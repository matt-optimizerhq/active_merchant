require 'json'

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

      # options can be accessed later through the instance variable @options
      # (superclass initializer sets this)
      def initialize(options = {})
        #puts "initialize called with options #{options}"
        requires!(options, :login, :password)
        super
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('authonly', money, post)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)

        commit('sale', money, post)
      end

      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, money, parameters)
        puts "commit() called with action=#{action}, money=#{money}, parameters=#{parameters}"
        case action
        when "sale"
          url_params = {
            :merchant_id       => "1234",
            :api_key           => "123",
            :td_amount         => money.to_s
          }
          # converts a hash to URL parameters (merchant_id=1234&api_key=...)
          url_params_encoded = url_params.to_query
          puts url_params_encoded

          # build complete URL
          url = "#{test_url}/createTransactionIdentifier.php?#{url_params_encoded}"
          puts url

          begin
            # passing nil for POST data
            # ssl_post() returns the response body as a string on success,
            # or raise a ResponseError exception
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

      # MC: I'm guessing the hash returned from this conforms to a format expected by
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

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end
    end
  end
end

