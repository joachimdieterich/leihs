# A Contract is a #Document containing #ContractLine s. It gets
# created from an #Order, once the #Order is acknowledged by an
# #InventoryPool manager.
#
# The page "Flow" inside the models.graffle document shows the
# various steps though which a #Document goes from #Order to
# finally closed Contract.
#
class Contract < Document

  belongs_to :inventory_pool # common for sibling classes
  belongs_to :user
  
  has_many :contract_lines, :dependent => :destroy, :order => 'start_date ASC, end_date ASC, contract_lines.created_at ASC' #Rails3.1# TODO ContractLin#default_scope
  has_many :item_lines, :dependent => :destroy, :order => 'start_date ASC, end_date ASC, contract_lines.created_at ASC'
  has_many :option_lines, :dependent => :destroy, :order => 'start_date ASC, end_date ASC, contract_lines.created_at ASC'
  has_many :models, :through => :item_lines, :uniq => true, :order => 'contract_lines.start_date ASC, contract_lines.end_date ASC, models.name ASC'
  has_many :items, :through => :item_lines, :uniq => false
  has_many :options, :through => :option_lines, :uniq => true

  # TODO validates_uniqueness [user_id, inventory_pool_id, status_const] if status_consts == Contract::UNSIGNED

  UNSIGNED = 1
  SIGNED = 2
  CLOSED = 3

  STATUS = {_("Unsigned") => UNSIGNED, _("Signed") => SIGNED, _("Closed") => CLOSED }

  def status_string
    n = STATUS.index(status_const)
    n.nil? ? status_const : n
  end

  # alias
  def lines( reload = false )
    contract_lines( reload )
  end

#########################################################################

  scope :unsigned, where(:status_const => Contract::UNSIGNED)
  scope :signed, where(:status_const => Contract::SIGNED)
  scope :closed, where(:status_const => Contract::CLOSED)
  scope :signed_or_closed, where(:status_const => [Contract::SIGNED, Contract::CLOSED])
  
  # OPTIMIZE use INNER JOIN (:joins => :contract_lines) -OR- union :unsigned + :signed (with lines) 
  scope :pending, select("DISTINCT contracts.*").
                  joins("LEFT JOIN contract_lines ON contract_lines.contract_id = contracts.id").
                  where(["contracts.status_const = :signed
                                         OR (contracts.status_const = :unsigned AND
                                             contract_lines.contract_id IS NOT NULL)",
                                        {:signed => Contract::SIGNED,
                                         :unsigned => Contract::UNSIGNED }])

  scope :by_inventory_pool, lambda { |inventory_pool| where(:inventory_pool_id => inventory_pool) }

#########################################################################

  scope :search, lambda { |query|
    return scoped if query.blank?
    
    sql = select("DISTINCT contracts.*").
      joins("LEFT JOIN `users` ON `users`.`id` = `contracts`.`user_id`").
      joins("LEFT JOIN `contract_lines` ON `contract_lines`.`contract_id` = `contracts`.`id`").
      joins("LEFT JOIN `options` ON `options`.`id` = `contract_lines`.`option_id`").
      joins("LEFT JOIN `models` ON `models`.`id` = `contract_lines`.`model_id`").
      joins("LEFT JOIN `items` ON `items`.`id` = `contract_lines`.`item_id`")

    query.split.each{|q|
      qq = "%#{q}%"
      sql = sql.where(arel_table[:id].eq(q).
                      or(arel_table[:note].matches(qq)).
                      or(User.arel_table[:login].matches(qq)).
                      or(User.arel_table[:firstname].matches(qq)).
                      or(User.arel_table[:lastname].matches(qq)).
                      or(User.arel_table[:badge_id].matches(qq)).
                      or(Model.arel_table[:name].matches(qq)).
                      or(Option.arel_table[:name].matches(qq)).
                      or(Item.arel_table[:inventory_code].matches(qq)))
    }
    sql
  }

  def self.filter2(options)
    sql = scoped
    options.each_pair do |k,v|
      case k
        when :inventory_pool_id
          sql = sql.where(k => v)
        when :status_const
          sql = sql.where(k => v)
      end
    end
    sql
  end
  
#########################################################################
  
  # TODO: we don't have a single place where we call sign without a current_user, except in a new test
  #       -> eliminate the default value and the assignement current_user ||=
  def sign(selected_lines = nil, current_user = nil)
    current_user ||= self.user
    selected_lines ||= self.contract_lines
 
    if selected_lines.empty? # sign is only possible if there is at least one line
      errors.add(:base, _("This contract is not signable because it doesn't have any contract lines."))
      false
    elsif selected_lines.all? {|l| l.purpose.nil? }
      errors.add(:base, _("This contract is not signable because none of the lines have a purpose."))
      false
    elsif selected_lines.any? {|l| l.item.nil? }
      errors.add(:base, _("This contract is not signable because some lines are not assigned."))
      false
    else
      transaction do
        update_attributes({:status_const => Contract::SIGNED, :created_at => Time.now}) 
        log_history(_("Contract %d has been signed by %s") % [self.id, self.user.name], current_user.id)
    
        # Forces handover date to be today.
        selected_lines.each {|cl|
          cl.update_attributes(:start_date => Date.today) if cl.start_date != Date.today 
        }
        
        unless (lines_for_new_contract = self.contract_lines - selected_lines).empty?
          new_contract = user.get_current_contract(self.inventory_pool)
          lines_for_new_contract.each do |cl|
            cl.update_attributes(:contract => new_contract)
          end
        end        
      end
      true
    end
  end

  def close
    update_attributes(:status_const => Contract::CLOSED)
  end

  def action
    if status_const == Contract::UNSIGNED
      :hand_over
    elsif status_const == Contract::SIGNED
      :take_back
    else
      nil
    end
  end

  ############################################

  def update_lines(line_ids, line_id_model_id, start_date, end_date, current_user_id) # TODO remove current_user_id when not used anymore
    ContractLine.transaction do
      lines.find(line_ids).each do |line|        
        line.start_date = Date.parse(start_date) if start_date
        line.end_date = Date.parse(end_date) if end_date

        # TODO remove log changes (use the new audits)
        change = ""
        # TODO the model swapping is not implemented on the client side
        if (new_model_id = line_id_model_id[line.id.to_s]) 
          line.model = line.contract.user.models.find(new_model_id) 
          change = _("[Model %s] ") % line.model 
        end
        change += line.changes.map do |c|
          what = c.first
          if what == "model_id"
            from = Model.find(from).to_s
            _("Swapped from %s ") % [from]
          else
            from = c.last.first
            to = c.last.last
            _("Changed %s from %s to %s") % [what, from, to]
          end
        end.join(', ')

        log_change(change, current_user_id) if line.save
      end
    end
  end

  ############################################

  # NOTE override the column attribute (until leihs 2 is switched off)
  def purpose
    nil
  end
  
  # NOTE override the column attribute (until leihs 2 is switched off)
  def purpose=(description)
    Purpose.create(description: description, contract_lines: lines.where(purpose_id: nil))
  end 

  def change_purpose(new_purpose, user_id)
    change = _("Purpose changed '%s' for '%s'") % [self.purpose.try(:description), new_purpose]
    log_change(change, user_id)
    self.purpose = new_purpose
  end  

end

