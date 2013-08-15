require 'json'
require 'pp'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SwipeCheckoutGateway < Gateway
      self.live_url = 'https://api.swipehq.com'
      self.test_url = 'http://10.1.1.88/mattc/hg/billing.swipehq.com/api'

      # The countries the gateway supports merchants from as 2 digit ISO country codes.
      # Swipe Checkout currently allows merchant signups from New Zealand and Canada.
      # MC: not sure if this directly maps to supported currencies in applications
      self.supported_countries = %w[ NZ ]

      self.default_currency = 'NZD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.swipehq.com/checkout'
      self.display_name = 'Swipe Checkout'
      self.money_format = :dollars

      # Swipe Checkout requires the merchant's email and API key for authorization.
      # (STUB)...
      def initialize(options = {})
        # MC: Note: options can be accessed later through the instance variable @options
        # (superclass initializer sets this)
        requires!(options, :login, :api_key)
        super
      end

      # Transfers funds immediately
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, creditcard, options)
        add_amount(post, money, options)

        commit('sale', money, post)
      end

      # NOTE: Swipe Checkout does not yet support authorize, capture, refund etc.

      # ======================================================================
      private

      def add_customer_data(post, creditcard, options)
        post[:email] = options[:email]
        post[:ip_address] = options[:ip]

        address = options[:billing_address] || options[:address]
        return if address.nil?

        post[:company] = address[:company]
        post[:first_name] = address[:name]   # stub
        post[:last_name] = "test"             # stub
        post[:address] = "#{address[:address1]}, #{address[:address2]}"
        post[:city] = address[:city]
        post[:country] = address[:country]
        post[:mobile] = address[:phone]     # stub

      end

      # add any details about the product or service being paid for
      def add_invoice(post, options)
        # store Shopify order ID in Swipe for merchant's records
        post[:td_user_data] = options[:order_id]
        post[:td_item] = options[:description]
        post[:td_description] = options[:description]
        post[:item_quantity] = "1"
      end

      # add credit card no, expiry, CVV, ...
      def add_creditcard(post, creditcard)
        post[:card_number] = creditcard.number
        post[:card_type] = creditcard.brand
        post[:name_on_card] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:card_expiry] = expdate(creditcard)
        post[:secure_number] = creditcard.verification_value
      end

      # Formats expiry dates as MMDD (source: blue_pay.rb)
      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def add_amount(post, money, options)
        post[:amount] = money.to_s

        # TODO convert 2 digit country codes to 3 digits, as supported by Swipe
        two_digit_cc = options[:currency] || currency(money)
        post[:currency] = two_digit_cc
      end

      def commit(action, money, parameters)
        #puts "commit() called with action=#{action}, money=#{money}, parameters=#{parameters}"
        case action
        when "sale"
          parameters[:merchant_id] = @options[:login]
          parameters[:api_key] = @options[:api_key]

          #puts "parameters ="
          #pp(parameters)

          # converts a hash to URL parameters (merchant_id=1234&api_key=...)
          encoded_params = parameters.to_query
          #encoded_params = post_data(action, parameters)
          #puts "encoded_params = #{encoded_params}"
          #puts "parameters.to_query = #{parameters.to_query}"

          # build complete URL
          url = "#{test_url}/createShopifyTransaction.php"
          #puts "full URL = #{url}"

          begin
            # ssl_post() returns the response body as a string on success,
            # or raises a ResponseError exception on failure
            response = ssl_post(url, encoded_params)
            #puts response

            # JSON parse the response body
            response_json = parse(response)
            #puts "response = #{response_json.to_s}"

            # response code and message params should always be present
            code = response_json["response_code"]
            message = response_json["message"]

            #puts "test = #{test?}"

            if code == 200
              result = response_json["data"]["result"]
              success = result == 'accepted'

              Response.new(success,
                           message,
                           response_json,
                           :test => test?)
            else
              Response.new(false,
                           message,
                           response_json,
                           :test => test?)
            end
          rescue ResponseError => e
            raw_response = e.response.body
            puts "ssl_post() with url #{url} raised ResponseError: #{e}"
            nil
          rescue JSON::ParserError
            json_error(raw_response)
          end
        end
      end

      # MC: Assuming the hash returned from this conforms to a format expected by
      # users of the commit() method...
      def json_error(raw_response)
        msg = 'Invalid response received from the Swipe Checkout API. ' +
          'Please contact support@optimizerhq.com if you continue to receive this message.' +
          " (The raw response returned by the API was #{raw_response.inspect})"

        {
          "error" => {
            "message" => msg
          }
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def message_from(response)
      end

#      # Returns params as URL-encoded form data for passing to Swipe gateway API
#      # via HTTP POST
#      def post_data(action, params = {})
#        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
#      end
    end
  end
end

