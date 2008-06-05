class Contract < Document

  belongs_to :user
  has_many :contract_lines, :dependent => :destroy
  has_and_belongs_to_many :printouts  # TODO , :dependent => :destroy

  acts_as_ferret :fields => [ :user_login, :lines_model_names ],
                 :store_class_name => true
                 # TODO union of results :or_default => true


  NEW = 1
  SIGNED = 2    
  # TODO ?? CLOSED = 3
  
  # alias
  def lines
    contract_lines
  end

#########################################################################

  # OPTIMIZE 
#  def start_date
#    lines.sort.first.start_date
##    d = read_attribute("start_date")
##    d.to_date
#  end
#
#  # OPTIMIZE 
#  def quantity
#    s = 0
#    lines.each {|l| s += l.quantity }
#    s
#  end

  attr_accessor(:start_date, :quantity)

   def visits(sd)
    self.start_date = sd
    self.quantity = 0
    lines.sort.each {|l| self.quantity += l.quantity if l.start_date == self.start_date }
    self
   end



#########################################################################

# finders provided by rails 2.1, but not yet recognized by rspec
  named_scope :new_contracts, :conditions => {:status_const => Contract::NEW}
  named_scope :signed_contracts, :conditions => {:status_const => Contract::SIGNED}

  named_scope :ready_for_hand_over, :select => 'contracts.*, contract_lines.start_date AS s',
                                    :joins => :contract_lines,
                                    :conditions => {:status_const => Contract::NEW,
                                                    'contract_lines.returned_date' => nil } ,
                                    :group => 'contract_lines.start_date',
                                    :order => 'contract_lines.start_date'

#  def self.new_contracts
#    find(:all, :conditions => {:status_const => Contract::NEW})
#  end
#
#  def self.signed_contracts
#    find(:all, :conditions => {:status_const => Contract::SIGNED})
#  end

#########################################################################


  def sign(contract_lines = nil)
    if contract_lines and contract_lines.any? { |cl| cl.item }
      update_attribute :status_const, Contract::SIGNED 

      # double check
      contract_lines.each {|cl| cl.update_attribute :start_date, Date.today if cl.start_date != Date.today }
      
      lines_for_new_contract = self.contract_lines - contract_lines
      if lines_for_new_contract
        new_contract = user.get_current_contract
        lines_for_new_contract.each do |cl|
          cl.update_attribute :contract, new_contract
        end
      end
    end
  end


  # TODO implement
  def to_pdf    
  end


end
