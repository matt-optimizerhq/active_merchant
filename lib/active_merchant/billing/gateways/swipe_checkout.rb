require 'json'
require 'pp'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SwipeCheckoutGateway < Gateway
      TRANSACTION_APPROVED_MSG = 'Transaction approved'
      TRANSACTION_DECLINED_MSG = 'Transaction declined'

      # by region
      LIVE_URLS = {
        'NZ' => 'https://api.swipehq.com',
        'CA' => 'https://api.swipehq.ca'
      }

      self.test_url = 'http://10.1.1.88/mattc/hg/billing.swipehq.com/api'

      TRANSACTION_API = '/createShopifyTransaction.php'

      # used to find the currencies a merchant can accept payments in,
      # which depends on the gateway/bank they're using
      # TODO expand on this
      CURRENCIES_API = '/fetchCurrencyCodes.php'

      # The countries the gateway supports merchants from as 2 digit ISO country codes.
      # Swipe Checkout currently allows merchant signups from New Zealand and Canada.
      self.supported_countries = %w[ NZ CA ]

      # TODO throw a SwipeCheckoutException if purchase currency isn't in this list
      SUPPORTED_CURRENCIES = %w[ AUD CAD CNY EUR GBP HKD JPY KRW NZD SGD USD ZAR ]

      self.default_currency = 'NZD'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'https://www.swipehq.com/checkout'
      self.display_name = 'Swipe Checkout'
      self.money_format = :dollars

      # Swipe Checkout requires the merchant's email and API key for authorization.
      # This can be found under Settings > API Credentials in your Swipe Checkout
      # merchant console.
      #
      # :region specifies which swipe domain to use (currently can be either NZ or CA).
      # Note that Merchant IDs are specific to a swipe domain - login will fail
      # if the wrong one is selected
      def initialize(options = {})
        # MC: Note: options can be accessed later through the instance variable @options
        # (superclass initializer sets this)
        requires!(options, :login, :api_key, :region)
        super
      end

      # Transfers funds immediately.
      # Note that Swipe Checkout only supports purchase at this stage
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

      # add any customer details to the request
      def add_customer_data(post, creditcard, options)
        post[:email] = options[:email]
        post[:ip_address] = options[:ip]

        address = options[:billing_address] || options[:address]
        return if address.nil?

        post[:company] = address[:company]

        # groups all names after the first into the last name param
        post[:first_name], post[:last_name] = address[:name].split(' ', 2)
        post[:address] = "#{address[:address1]}, #{address[:address2]}"
        post[:city] = address[:city]
        post[:country] = address[:country]
        post[:mobile] = address[:phone]     # API only has a "mobile" field, no "phone"
      end

      # add any details about the product or service being paid for
      def add_invoice(post, options)
        # store shopping-cart order ID in Swipe for merchant's records
        post[:td_user_data] = options[:order_id] if options[:order_id]
        post[:td_item] = options[:description] if options[:description]
        post[:td_description] = options[:description] if options[:description]
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
        
        # Assuming ISO_3166-1 (3 character) currency code (TODO: confirm this)
        post[:currency] = options[:currency] || currency(money)
      end

      def commit(action, money, parameters)
        case action
        when "sale"

          # make sure currency is supported
          #if !supported_currency? parameters[:currency]
          #  return build_error_response("Unsupported currency \"#{parameters[:currency]}\"")
          #end

          begin
            # make sure currency is supported by merchant
            response = call_api CURRENCIES_API
            code = response["response_code"]
            message = response["message"]
            if code == 200  # OK
              supported_currencies = response['data'].values
              currency = parameters[:currency]
              if !supported_currencies.include? currency
                return build_error_response("Unsupported currency \"#{currency}\"", response)
              end
            else
              return build_error_response(message, response)
            end
            
            # JSON parse the response body
            response = call_api TRANSACTION_API, parameters

            # response code and message params should always be present
            code = response["response_code"]
            message = response["message"]

            #puts "test = #{test?}"

            if code == 200  # OK
              result = response["data"]["result"]
              success = result == 'accepted' || (test? && result == 'test-accepted')

              Response.new(success,
                           success ?
                           TRANSACTION_APPROVED_MSG :
                           TRANSACTION_DECLINED_MSG,
                           response,
                           :test => test?)
            else
              build_error_response(message, response)
            end
          rescue ResponseError => e
            raw_response = e.response.body
            build_error_response("ssl_post() with url #{url} raised ResponseError: #{e}")
          rescue JSON::ParserError => e
            msg = 'Invalid response received from the Swipe Checkout API. ' +
                  'Please contact support@optimizerhq.com if you continue to receive this message.' +
                  " (Full error message: #{e})"
            build_error_response(msg)
          end
        end
      end

      # Returns the parsed JSON response from an API call as a hash
      def call_api(api, params=nil)
        if !params then params = {} end
        params[:merchant_id] = @options[:login]
        params[:api_key] = @options[:api_key]
        region = @options[:region]
        url = get_base_url(region) + api

        # ssl_post() returns the response body as a string on success,
        # or raises a ResponseError exception on failure
        #parse( ssl_post( url, params.to_query ) )
        text = ssl_post( url, params.to_query )
        #puts "in call_api(#{api}), raw response text = #{text}"
        parse(text)
      end

      def parse(body)
        JSON.parse(body)
      end

      def get_base_url(region)
          (test?) ? self.test_url : LIVE_URLS[region]
          #LIVE_URLS[region]    # test against live
      end

#      def supported_currency?(currency_code)
#        # TODO update to use fetchCurrencies API, remove hard-coded SUPPORTED_CURRENCIES
#        SUPPORTED_CURRENCIES.include? currency_code
#      end

      def build_error_response(message, params={})
        Response.new(false,
                     message,
                     params,
                     :test => test?)
      end
    end
  end
end

