class Invoice
  attr_accessor :client, :reference, :shipper, :items

  def self.for(data)
    invoice = new(data)
    invoice.client = Client.new(data)
    invoice.items = [Item.new(data)]
    invoice
  end

  def get_binding
    binding
  end

  def total
    @items.map(&:total).reduce(:+)
  end

  def qty_total
    @items.map(&:qty).reduce(:+)
  end

  def initialize(params)
    @reference = params['reference_number']
    @shipper   = params['shipper']
  end

  class Client
    attr_accessor :name, :address, :mailbox

    def initialize(params)
      @name = params['fullname']
      @address = params['address']
      @mailbox = params['mbe_address']
    end
  end

  class Item
    attr_accessor :package, :name, :value, :qty

    def initialize(params)
      @name = params['item_name']
      @package = params['package'] ||  '1'
      @value = params['item_cost']
      @qty = params['qty']  || '1'
    end

    def total
      @qty.to_i * @value.to_f
    end
  end
end
