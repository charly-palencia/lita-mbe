require_relative '../../models/invoice'
require 'ostruct'
require 'wicked_pdf'
require 'aws-sdk'

module Lita
  module Handlers
    class Mbe < Handler
      route(/^mbe generate$/, command: true) do |response|
        user = response.user
        step = redis.get("user:question:#{user.id}")  || 'start'
        user_information = redis.hgetall("user:#{user.id}")
        if !user_information['fullname'].nil?
          step = 'mbe_address'
        end

        case step
        when 'start'
          response.reply('what is your fullname?')
          redis.set("user:question:#{user.id}", :fullname)

        when 'mbe_address'
          response.reply('what is the reference number?')
          redis.set("user:question:#{user.id}", :reference_number)
        end
      end

      route(/^(?!mbe generate).*/, command: true) do |response|
        message, recipient = response.matches.first
        user = response.user
        step = redis.get("user:question:#{user.id}")
        return unless step

        case step
        when 'fullname'
          response.reply('what is your address?')
          redis.set("user:question:#{user.id}", :user_address)
          redis.hsetnx("user:#{user.id}", :fullname, message)

        when 'user_address'
          response.reply('what is your mbe address?')
          redis.set("user:question:#{user.id}", :mbe_address)
          redis.hsetnx("user:#{user.id}", :user_address, message)

        when 'mbe_address'
          response.reply('what is the reference number?')
          redis.set("user:question:#{user.id}", :reference_number)
          redis.hsetnx("user:#{user.id}", :mbe_address, message)

        when 'reference_number'
          response.reply('what is the item name?')
          redis.set("user:question:#{user.id}", :item_name)
          redis.hsetnx("user:#{user.id}", :reference_number, message)

        when 'item_name'
          response.reply('what is the item cost?')
          redis.set("user:question:#{user.id}", :item_cost)
          redis.hsetnx("user:#{user.id}", :item_name, message)

        when 'item_cost'
          response.reply(':)')
          redis.del("user:question:#{user.id}")
          redis.hsetnx("user:#{user.id}", :item_cost, message)

          user_information = redis.hgetall("user:#{user.id}")
          @invoice = Invoice.for(user_information)

          path  =   File.expand_path(File.join(File.dirname(__FILE__), "../../templates/invoice.html.erb"))
          html  = ERB.new(File.read(path)).result(@invoice.get_binding)

          pdf = WickedPdf.new.pdf_from_string(html)
          file = Tempfile.open('invoice.pdf') do |file|
            file << pdf
          end

          Aws.config.update({
              region: 'us-west-2',
              credentials: Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_SECRET_ACCESS_KEY']),
          })

          s3 = AWS::S3.new

          response.reply("borrado") if s3.bucket['lita-mbe'].objects["invoice-#{user.id}.pdf"].delete
          s3.bucket['lita-mbe'].objects.create("invoice-#{user.id}.pdf", open(file.path))

          # AWS::S3::S3Object.store("invoice-#{user.id}.pdf", open(file.path), 'lita-mbe', access: :public_read)

          response.reply("http://s3.amazonaws.com/lita-mbe/invoice-#{user.id}.pdf")
        end
      end

      Lita.register_handler(self)
    end
  end
end
