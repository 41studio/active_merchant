module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class XenditGateway < Gateway
      self.test_url = 'https://api.xendit.co/test'
      self.live_url = 'https://api.xendit.co/live'

      self.supported_countries = ['US', 'ID']
      self.default_currency = 'IDR'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://api.xendit.co/'
      self.display_name = 'Xendit'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :public_key, :secret_key, :validation_token)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('credit_card_charges', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
        post[:first_name] = options[:first_name]
        post[:last_name] = options[:last_name]
        post[:email] = options[:email]
      end

      def add_address(post, creditcard, options)
        if billing_address = options[:billing_address] || options[:address]
          post[:company]    = billing_address[:company]
          post[:address1]   = billing_address[:address1]
          post[:address2]   = billing_address[:address2]
          post[:city]       = billing_address[:city]
          post[:state]      = billing_address[:state]
          post[:zip]        = billing_address[:zip]
          post[:country]    = billing_address[:country]
          post[:phone]      = billing_address[:phone]
        end

        if shipping_address = options[:shipping_address]
          post[:shipping_firstname] = shipping_address[:first_name]
          post[:shipping_lastname]  = shipping_address[:last_name]
          post[:shipping_company]   = shipping_address[:company]
          post[:shipping_address1]  = shipping_address[:address1]
          post[:shipping_address2]  = shipping_address[:address2]
          post[:shipping_city]      = shipping_address[:city]
          post[:shipping_state]     = shipping_address[:state]
          post[:shipping_zip]       = shipping_address[:zip]
          post[:shipping_country]   = shipping_address[:country]
          post[:shipping_email]     = shipping_address[:email]
        end
      end

      def add_invoice(post, money, options)
        post[:external_id] = options[:external_id]
        post[:payer_email] = options[:email]
        post[:desciption] = options[:desciption]
        post[:should_send_email] = false
        post[:callback_virtual_account_id] = options[:callback_virtual_account_id]
        post[:merchant_site_url] = options[:merchant]
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, creditcard)
        post[:cc] = creditcard.number
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        post[:expire] = "#{month}/#{year[2..3]}"
      end

      def parse(body)
        return {} unless body
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        (response[:status] =~ /success/i || response[:status] =~ /ok/i)
      end

      def message_from(response)
        (response[:message] || response[:status])
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
