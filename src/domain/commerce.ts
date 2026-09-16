export interface CartLine {
  id: string;
  productId: string;
  variantId: string;
  quantity: number;
  addedAt: number;
}

export interface Cart {
  lines: CartLine[];
}

export interface Address {
  fullName: string;
  phone: string;
  line1: string;
  line2: string;
  city: string;
  state: string;
  pincode: string;
}

export interface CheckoutDraft {
  email: string;
  phone: string;
  address: Address;
  deliveryMethod: "standard" | "express";
  coupon: string;
  paymentMethod: "card" | "upi" | "cod";
}

export interface OrderItem {
  productId: string;
  variantId: string;
  title: string;
  brandName: string;
  size: string;
  color: string;
  quantity: number;
  price: number;
}

export interface Order {
  orderNumber: string;
  createdAt: number;
  status: "placed" | "packed" | "shipped" | "delivered" | "cancelled";
  items: OrderItem[];
  subtotal: number;
  shipping: number;
  total: number;
  address: Address;
  paymentMethod: string;
  prototype: true;
}

export interface Profile {
  name: string;
  email: string;
  phone: string;
  signedIn: boolean;
}
