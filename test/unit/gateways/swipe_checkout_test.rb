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

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '', response.authorization
    assert response.test?
  end

#  def test_unsuccessful_request
#    @gateway.expects(:ssl_post).returns(failed_purchase_response)
#
#    assert response = @gateway.purchase(@amount, @credit_card, @options)
#    assert_failure response
#    assert response.test?
#  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    '{}'  # stub
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
  end
end
