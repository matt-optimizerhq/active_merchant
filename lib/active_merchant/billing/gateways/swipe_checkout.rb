require 'json'
require 'pp'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SwipeCheckoutGateway < Gateway
      self.live_url = self.test_url = 'https://api.swipehq.com'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['NZ']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.swipehq.com/checkout'
      self.display_name = 'Swipe Checkout'
      self.money_format = :dollars

      # Note: options can be accessed later through the instance variable @options
      # (superclass initializer sets this)
      def initialize(options = {})
        requires!(options, :login, :api_key)
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_customer_data(post, creditcard, options)
        add_amount(post, money, options)

        commit('sale', money, post)
      end

      # ======================================================================
      private

      def add_customer_data(post, creditcard, options)
        post[:td_email] = options[:email]

        address = options[:billing_address] || options[:address]
        return if address.nil?

        post[:td_company] = address[:company]
        post[:td_first_name] = address[:name]   # stub
        #post[:td_last_name] = "test"
        post[:td_address] = "#{address[:address1]}, #{address[:address2]}"
        post[:td_city] = address[:city]
        post[:td_country] = address[:country]
        post[:td_phone] = address[:phone]

      end

      # add any details about the product or service being paid for
      def add_invoice(post, options)
          post[:td_item] = options[:description]
      end

      def add_creditcard(post, creditcard)
        # add credit card no, expiry...
      end

      def add_amount(post, money, options)
        post[:td_amount] = money.to_s

        # TODO: convert to 3 digit country codes supported by Swipe
        two_digit_cc = options[:currency] || currency(money)
        post[:td_currency] = two_digit_cc
      end


      def commit(action, money, parameters)
        #puts "commit() called with action=#{action}, money=#{money}, parameters=#{parameters}"
        case action
        when "sale"
          parameters[:merchant_id]      = @options[:login]
          parameters[:api_key]          = @options[:api_key]

          puts "parameters ="
          pp(parameters)

          # converts a hash to URL parameters (merchant_id=1234&api_key=...)
          encoded_params = parameters.to_query
          #puts encoded_params

          # build complete URL
          url = "#{test_url}/createTransactionIdentifier.php?#{encoded_params}"
          puts "full URL = #{url}"

          begin
            # passing nil for POST data
            # ssl_post() returns the response body as a string on success,
            # or raises a ResponseError exception on failure
            response = ssl_post(url, nil)
            puts response

            # JSON parse the response body
            response_json = parse(response)
            puts response_json.to_s
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

      def post_data(action, parameters = {})
      end
    end
  end
end

