# frozen_string_literal: true

# No MySQL table, reading a query result
class ReservationsBundle < ActiveRecord::Base
  include Delegation::ReservationsBundle
  audited

  class << self
    include BundleFinder
  end

  def readonly?
    true
  end

  self.table_name = 'reservations'

  default_scope do
    # NOTE: MAX(reservations.status) AS status
    # this is a trick to get 'signed' in case
    # there are both 'signed' and 'closed' reservations
    select(<<-SQL)
      IFNULL(reservations.contract_id,
             CONCAT_WS('_',
                       reservations.status,
                       reservations.user_id,
                       reservations.inventory_pool_id)) AS id,
      MAX(reservations.status) AS status,
      reservations.user_id,
      reservations.inventory_pool_id,
      reservations.delegated_user_id,
      IF(SUM(groups.is_verification_required) > 0, 1, 0) AS verifiable_user,
      COUNT(partitions.id) > 0 AS verifiable_user_and_model,
      MAX(reservations.created_at) AS created_at
    SQL
    .joins(<<-SQL)
      LEFT JOIN (groups_users, groups)
      ON reservations.user_id = groups_users.user_id
      AND groups_users.group_id = groups.id
      AND groups.is_verification_required = 1
      AND reservations.inventory_pool_id = groups.inventory_pool_id
    SQL
    .joins(<<-SQL)
      LEFT JOIN partitions
      ON partitions.group_id = groups.id
      AND partitions.model_id = reservations.model_id
    SQL
    .group(<<-SQL)
      IFNULL(reservations.contract_id, reservations.status),
             reservations.user_id,
             reservations.inventory_pool_id
    SQL
    .order(nil)
  end

  def id
    r = id_before_type_cast
    if r.nil? # it is not persisted
      "#{status}_#{user_id}_#{inventory_pool_id}"
    elsif r.is_a? String and r.include?('_')
      r
    else
      r.to_i
    end
  end

  belongs_to :inventory_pool
  belongs_to :user

  belongs_to :contract, foreign_key: :id
  delegate :note, to: :contract

  LINE_CONDITIONS = \
    lambda do |r|
      where(<<-SQL,
        (reservations.status IN ('signed', 'closed')
         AND reservations.contract_id = ?)
        OR
        (reservations.status NOT IN ('signed', 'closed')
         AND reservations.user_id = ?
         AND reservations.status = ?)
      SQL
            r.id,
            r.user_id,
            r.status)
    end

  has_many(:reservations,
           LINE_CONDITIONS,
           foreign_key: :inventory_pool_id,
           primary_key: :inventory_pool_id)
  has_many(:item_lines,
           LINE_CONDITIONS,
           foreign_key: :inventory_pool_id,
           primary_key: :inventory_pool_id)
  has_many(:option_lines,
           LINE_CONDITIONS,
           foreign_key: :inventory_pool_id,
           primary_key: :inventory_pool_id)
  has_many :models, -> { order('models.product ASC').uniq }, through: :item_lines
  has_many :items, through: :item_lines
  has_many :options, -> { uniq }, through: :option_lines

  # NOTE we need this method because the association
  # has a inventory_pool_id as primary_key
  def reservation_ids
    reservations.pluck :id
  end

  #######################################################

  STATUSES = [:unsubmitted, :submitted, :rejected, :approved, :signed, :closed]

  def status
    read_attribute(:status).to_sym
  end

  STATUSES.each do |status|
    scope status, -> { where(status: status) }
  end

  scope :signed_or_closed, -> { where(status: [:signed, :closed]) }

  #######################################################

  scope :with_verifiable_user, -> { having('verifiable_user = 1') }
  scope(:with_verifiable_user_and_model,
        -> { having('verifiable_user_and_model = 1') })
  scope :no_verification_required, -> { having('verifiable_user_and_model != 1') }

  def to_be_verified?
    verifiable_user_and_model == 1
  end

  #######################################################

  scope(:search,
        (lambda do |query|
          return all if query.blank?

          sql = uniq
            .joins('INNER JOIN users ON users.id = reservations.user_id')
            .joins(<<-SQL)
              LEFT JOIN contracts ON reservations.id = contracts.id
              AND reservations.status IN ('signed', 'closed')
            SQL
            .joins('LEFT JOIN options ON options.id = reservations.option_id')
            .joins('LEFT JOIN models ON models.id = reservations.model_id')
            .joins('LEFT JOIN items ON items.id = reservations.item_id')
            .joins('LEFT JOIN purposes ON purposes.id = reservations.purpose_id')

          query.split.each do |q|
            qq = "%#{q}%"
            sql = sql.where(
              # "reservations.id = '#{q}' OR
              #  CONCAT_WS(' ',
              #            contracts.note,
              #            users.login,
              #            users.firstname,
              #            users.lastname,
              #            users.badge_id,
              #            models.manufacturer,
              #            models.product,
              #            models.version,
              #            options.product,
              #            options.version,
              #            items.inventory_code,
              #            items.properties) LIKE '%#{qq}%'"

              # NOTE we cannot use eq(q) because alphanumeric string is truncated
              # and casted to integer, causing wrong matches (contracts.id)
              arel_table[:contract_id]
                .eq(q.numeric? ? q : 0)
                .or(Contract.arel_table[:note].matches(qq))
                .or(User.arel_table[:login].matches(qq))
                .or(User.arel_table[:firstname].matches(qq))
                .or(User.arel_table[:lastname].matches(qq))
                .or(User.arel_table[:badge_id].matches(qq))
                .or(Model.arel_table[:manufacturer].matches(qq))
                .or(Model.arel_table[:product].matches(qq))
                .or(Model.arel_table[:version].matches(qq))
                .or(Option.arel_table[:product].matches(qq))
                .or(Option.arel_table[:version].matches(qq))
                .or(Item.arel_table[:inventory_code].matches(qq))
                .or(Item.arel_table[:properties].matches(qq))
                .or(Purpose.arel_table[:description].matches(qq)))
          end
          sql
        end))

  ############################################

  def self.filter(params, user = nil, inventory_pool = nil)
    contracts = if user
                  user.reservations_bundles
                elsif inventory_pool
                  inventory_pool.reservations_bundles
                else
                  all
                end

    contracts = contracts.where(status: params[:status]) if params[:status]

    unless params[:search_term].blank?
      contracts = contracts.search(params[:search_term])
    end

    contracts = if params[:no_verification_required]
                  contracts.no_verification_required
                elsif params[:to_be_verified]
                  contracts.with_verifiable_user_and_model
                elsif params[:from_verifiable_users]
                  contracts.with_verifiable_user
                else
                  contracts
                end

    contracts = contracts.where(id: params[:id]) if params[:id]

    if r = params[:range]
      created_at_date = \
        Arel::Nodes::NamedFunction.new('CAST',
                                       [arel_table[:created_at].as('DATE')])
      if r[:start_date]
        contracts = contracts.where(created_at_date.gteq(r[:start_date]))
      end
      if r[:end_date]
        contracts = contracts.where(created_at_date.lteq(r[:end_date]))
      end
    end

    contracts = contracts.order(arel_table[:created_at].desc)

    unless params[:paginate] == 'false'
      contracts = contracts.default_paginate params
    end
    contracts
  end

  ############################################

  def min_date
    unless reservations.blank?
      # min(&:start_date) does not work here
      # rubocop:disable Style/SymbolProc
      reservations.min { |x| x.start_date }[:start_date]
      # rubocop:enable Style/SymbolProc
    end
  end

  def max_date
    unless reservations.blank?
      # min(&:end_date) does not work here
      # rubocop:disable Style/SymbolProc
      reservations.max { |x| x.end_date }[:end_date]
      # rubocop:enable Style/SymbolProc
    end
  end

  def max_range
    return nil if reservations.blank?
    line = reservations.max_by { |x| (x.end_date - x.start_date).to_i }
    (line.end_date - line.start_date).to_i + 1
  end

  ############################################

  def time_window_min
    reservations.minimum(:start_date) || Time.zone.today
  end

  def time_window_max
    reservations.maximum(:end_date) || Time.zone.today
  end

  def next_open_date(x)
    x ||= Time.zone.today
    if inventory_pool
      inventory_pool.next_open_date(x)
    else
      x
    end
  end

  ############################################

  def add_lines(quantity,
                model,
                _current_user,
                start_date = nil,
                end_date = nil,
                delegated_user_id = nil)
    if end_date and start_date and end_date < start_date
      end_date = start_date
    end

    attrs = { inventory_pool: inventory_pool,
              status: status,
              quantity: 1,
              model: model,
              start_date: start_date || time_window_min,
              end_date: end_date || next_open_date(time_window_max),
              delegated_user_id: delegated_user_id || self.delegated_user_id }

    new_lines = quantity.to_i.times.map do
      line = user.item_lines.create(attrs) do |l|
        if status == :submitted and reservations.first.try :purpose
          l.purpose = reservations.first.purpose
        end
      end
      line
    end

    new_lines
  end

  ################################################################

  def remove_line(line)
    if [:unsubmitted, :submitted, :approved].include?(status) \
        and reservations.include?(line) \
        and line.destroy
      true
    else
      false
    end
  end

  ############################################

  def purpose_descriptions
    # join purposes
    reservations
      .sort
      .map { |x| x.purpose.to_s }
      .uniq
      .delete_if(&:blank?)
      .join('; ')
  end
  alias_method :purpose, :purpose_descriptions

  ############################################

  # TODO: dry with Reservation
  def target_user
    if user.delegation? and delegated_user
      delegated_user
    else
      user
    end
  end

  def submit(purpose_description = nil)
    # TODO: relate to Application Settings (required_purpose)
    if purpose_description
      purpose = Purpose.create description: purpose_description
      reservations.each { |cl| cl.purpose = purpose }
    end

    if approvable?
      reservations.each { |cl| cl.update_attributes(status: :submitted) }

      Notification.order_submitted(self, false)
      Notification.order_received(self, true)
      true
    else
      false
    end
  end

  ############################################

  def approvable?
    reservations.all?(&:approvable?)
  end

  def approve(comment, send_mail = true, current_user = nil, force = false)
    if approvable? \
        or (force and current_user.has_role?(:lending_manager, inventory_pool))
      reservations.each { |cl| cl.update_attributes(status: :approved) }
      begin
        Notification.order_approved(self, comment, send_mail, current_user)
      rescue Exception => exception
        # archive problem in the log, so the admin/developper
        # can look up what happened
        logger.error "#{exception}\n    #{exception.backtrace.join("\n    ")}"
        message = \
          _('The following error happened while sending ' \
            "a notification email to %{email}:\n") \
          % { email: target_user.email } \
          + "#{exception}.\n" \
          + _('That means that the user probably did not get the approval mail ' \
              'and you need to contact him/her in a different way.')

        self.errors.add(:base, message)
      end
      true
    else
      false
    end
  end

  def reject(comment, current_user)
    reservations.all? { |line| line.update_attributes(status: :rejected) } \
      and Notification.order_rejected(self, comment, true, current_user)
  end

  def sign(current_user, selected_lines, note = nil, delegated_user_id = nil)
    transaction do
      contract = Contract.create do |contract|
        contract.note = note

        selected_lines.each do |cl|
          attrs = {
            contract: contract,
            status: :signed,
            handed_over_by_user_id: current_user.id
          }

          if delegated_user_id
            attrs[:delegated_user] = user.delegated_users.find(delegated_user_id)
          end

          # Forces handover date to be today.
          attrs[:start_date] = Time.zone.today if cl.start_date != Time.zone.today

          cl.update_attributes(attrs)

          contract.reservations << cl
        end
      end
      contract
    end
  end

  def handed_over_by_user
    if [:signed, :closed].include? status
      reservations.first.handed_over_by_user
    end
  end

  ################################################################

  def total_quantity
    reservations.sum(:quantity)
  end

  def total_price
    reservations.to_a.sum(&:price)
  end
end
