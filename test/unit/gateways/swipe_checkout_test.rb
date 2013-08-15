require 'test_helper'

class SwipeCheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = SwipeCheckoutGateway.new(
                 :login => '40A67A96A6CF4',
                 :api_key => '9795affd2fb06755a50e3b2c96ab2bebc93f1f5f16af825d3b702d8418ad6a86'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_supported_countries
    assert @gateway.supported_countries == ['NZ', 'CA']
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_successful_test_purchase
    @gateway.expects(:ssl_post).returns(successful_test_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response   # "test-accepted" should be returned as a failure
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_test_purchase
    @gateway.expects(:ssl_post).returns(failed_test_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_invalid_card
    @gateway.expects(:ssl_post).returns(failed_purchase_response_invalid_card)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_system_error
    @gateway.expects(:ssl_post).returns(failed_purchase_response_system_error)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_incorrect_amount
    @gateway.expects(:ssl_post).returns(failed_purchase_response_incorrect_amount)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_access_denied
    @gateway.expects(:ssl_post).returns(failed_purchase_response_access_denied)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request_not_enough_parameters
    @gateway.expects(:ssl_post).returns(failed_purchase_response_not_enough_parameters)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_ensure_does_not_respond_to_authorize
    assert !@gateway.respond_to?(:authorize)
  end

  def test_ensure_does_not_respond_to_void
    assert !@gateway.respond_to?(:void)
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_ensure_does_not_respond_to_unstore
    assert !@gateway.respond_to?(:unstore)
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "accepted"}}'
  end

  def successful_test_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "test-accepted"}}'
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "declined"}}'
  end

  def failed_test_purchase_response
    '{"response_code": 200, "message": "OK", "data": {"tx_transaction_id": "00000000000000", "result": "test-declined"}}'
  end

  def failed_purchase_response_invalid_card
    build_failed_response 303, 'Invalid card data'
  end

  def failed_purchase_response_system_error
    build_failed_response 402, 'System error'
  end

  def failed_purchase_response_incorrect_amount
    build_failed_response 302, 'Incorrect amount'
  end

  def failed_purchase_response_access_denied
    build_failed_response 400, 'System error'
  end

  def failed_purchase_response_not_enough_parameters
    build_failed_response 403, 'Not enough parameters'
  end

  def build_failed_response(code, message)
    "{\"response_code\": #{code}, \"message\": \"#{message}\"}"
  end
end
