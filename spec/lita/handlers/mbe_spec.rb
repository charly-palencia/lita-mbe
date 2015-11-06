require "spec_helper"

describe Lita::Handlers::Mbe, lita_handler: true do
  let(:current_step){ subject.redis.get("user:question:#{user.id}") }

  it { is_expected.to route_command('mbe generate') }

  describe "#generate route" do
    context "with existing user" do
      let(:attributes){ { name: user.name, address: 'a742 Evergreen Terrace', mailbox: 'col91823'} }

      before do
        subject.redis.hmset("user:#{user.id}", *attributes)
        send_command('mbe generate')
      end

      it "doesn't ask about user information" do
        expect(replies.last).to eq("what is the reference number?")
        expect(current_step).to eq('reference_number')
      end
    end

    context "with new user" do
      before do
        send_command('mbe generate')
      end

      it "asks about fullname" do
        expect(replies.last).to eq("what is your fullname?")
        expect(current_step).to eq('fullname')
      end
    end
  end

  describe "full steps" do
    let(:steps){
      {
        start: {
          request: 'mbe generate',
          expected_reply: 'what is your fullname?',
          expected_step: 'fullname'
        },
        fullname: {
          request: 'bart Olomeo',
          expected_reply: 'what is your address?',
          expected_step: 'user_address',
          value: 'bart Olomeo'
        },
        user_address: {
          request: 'a742 Evergreen Terrace',
          expected_reply: 'what is your mbe address?',
          expected_step: 'mbe_address'
        },
        mbe_address: {
          request: 'COL4562',
          expected_reply: 'what is the reference number?',
          expected_step: 'reference_number'
        },
        reference_number: {
          request: 'REF162531273',
          expected_reply: 'what is the item name?',
          expected_step: 'item_name'
        },
        item_name: {
          request: 'toy',
          expected_reply: 'what is the item cost?',
          expected_step: 'item_cost'
        },
        item_cost: {
          request: '2',
          expected_reply: ':)',
          expected_step: nil
        }
      }
    }

    it 'follows the steps' do
      steps.each_with_index  do |values|
        key, step = values
        send_command(step[:request])
        current_step= subject.redis.get("user:question:#{user.id}")
        user_information = subject.redis.hgetall("user:#{user.id}")
        expect(replies.last).to eq(step[:expected_reply])
        expect(current_step).to eq(step[:expected_step])
        expect(user_information[key.to_s]).to_not be_nil unless key == :start
      end
    end
  end

  describe "download file" do
    let(:attributes){ { name: user.name, address: 'a742 Evergreen Terrace', mailbox: 'col91823', address: 'addres', mbe_address: 'col123', reference: 'asdas', cost: '2', name: 'toy' }}

    before do
      subject.redis.hmset("user:#{user.id}", *attributes)
e     subject.redis.set("user:question:#{user.id}", :item_cost)
      send_command('2')
    end

    it 'downloads a pdf file' do

    end
  end
end
