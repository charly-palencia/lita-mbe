require_relative '../../models/invoice'
require 'wicked_pdf'

module Lita
  module Handlers
    class Mbe < Handler
      route(/^mbe generate$/, command: true) do |response|
        user = response.user
        step = redis.get("user:question:#{user.id}")  || 'start'
        user_information = redis.hgetall("user:#{user.id}")
        if !user_information['name'].nil?
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

          if robot.config.robot.adapter == :slack
            user_information = redis.hgetall("user:#{user.id}")
            @invoice = Invoice.for(user_information)

            path  =   File.expand_path(File.join(File.dirname(__FILE__), "../../templates/invoice.html.erb"))
            html  = ERB.new(File.read(path)).result(@invoice.get_binding)

            pdf = WickedPdf.new.pdf_from_string(html)
            robot.chat_service.send_attachment(response, pdf)
          end
        end
      end

      Lita.register_handler(self)
    end
  end
end