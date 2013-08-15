require 'test_helper'

class RemoteSwipeCheckoutTest < Test::Unit::TestCase

  def setup
    @gateway = SwipeCheckoutGateway.new(fixtures(:swipe_checkout))

    @amount = 100
    @accepted_card = credit_card('1234123412341234')
    @declined_card = credit_card('1111111111111111')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @accepted_card, @options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction declined', response.message
  end

  def test_invalid_login
    gateway = SwipeCheckoutGateway.new(
                :login => 'invalid',
                :api_key => 'invalid'
              )
    assert response = gateway.purchase(@amount, @accepted_card, @options)
    assert_failure response
    assert_equal 'Access Denied', response.message
  end

end
