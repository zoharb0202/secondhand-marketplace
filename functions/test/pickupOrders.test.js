const test = require('node:test');
const assert = require('node:assert');

const {lineItems, qtyOf, PAY_ON_PICKUP} = require('../src/pickupOrders');

test('a single-product order yields one line item priced from productPrice', () => {
  assert.deepStrictEqual(lineItems({productId: 'p1', productPrice: 120}), [{productId: 'p1', price: 120}]);
});

test('a multi-item order yields every line item', () => {
  const order = {productId: 'p1', items: [{productId: 'p1', price: 10}, {productId: 'p2', price: 25.5}]};
  assert.deepStrictEqual(lineItems(order), [{productId: 'p1', price: 10}, {productId: 'p2', price: 25.5}]);
});

test('quantity defaults to 1 and never drops below it', () => {
  assert.strictEqual(qtyOf({}, 'p1'), 1);
  assert.strictEqual(qtyOf({quantityByProductId: {p1: 3}}, 'p1'), 3);
  assert.strictEqual(qtyOf({quantityByProductId: {p1: 0}}, 'p1'), 1);
  assert.strictEqual(qtyOf({quantityByProductId: {p1: 'junk'}}, 'p1'), 1);
});

test('pay-on-pickup wire value matches the client', () => {
  assert.strictEqual(PAY_ON_PICKUP, 'pay_on_pickup');
});
