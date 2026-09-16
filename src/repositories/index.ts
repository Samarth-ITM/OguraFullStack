import { resolveDataMode } from "@/config/dataMode";
import {
  mockCatalogRepository,
  mockCartRepository,
  mockWishlistRepository,
  mockAccountRepository,
  mockCheckoutRepository,
  mockSellerRepository,
  mockReturnsRepository,
  mockAdminRepository,
} from "./mock";
import { backendCatalogRepository } from "./backend/catalog";
import { backendCartRepository } from "./backend/cart";
import { backendWishlistRepository } from "./backend/wishlist";
import { backendAccountRepository } from "./backend/account";
import { backendCheckoutRepository } from "./backend/checkout";
import { backendSellerRepository } from "./backend/seller";
import { backendReturnsRepository } from "./backend/returns";
import { backendAdminRepository } from "./backend/admin";

export function getActiveRepositories() {
  const mode = resolveDataMode();
  if (mode === "mock") {
    return {
      catalog: mockCatalogRepository,
      cart: mockCartRepository,
      wishlist: mockWishlistRepository,
      account: mockAccountRepository,
      checkout: mockCheckoutRepository,
      seller: mockSellerRepository,
      returns: mockReturnsRepository,
      admin: mockAdminRepository,
    };
  }
  return {
    catalog: backendCatalogRepository,
    cart: backendCartRepository,
    wishlist: backendWishlistRepository,
    account: backendAccountRepository,
    checkout: backendCheckoutRepository,
    seller: backendSellerRepository,
    returns: backendReturnsRepository,
    admin: backendAdminRepository,
  };
}

export const catalogRepository = new Proxy({} as typeof backendCatalogRepository, {
  get(_target, prop) {
    return (getActiveRepositories().catalog as any)[prop];
  },
});

export const cartRepository = new Proxy({} as typeof backendCartRepository, {
  get(_target, prop) {
    return (getActiveRepositories().cart as any)[prop];
  },
});

export const wishlistRepository = new Proxy({} as typeof backendWishlistRepository, {
  get(_target, prop) {
    return (getActiveRepositories().wishlist as any)[prop];
  },
});

export const accountRepository = new Proxy({} as typeof backendAccountRepository, {
  get(_target, prop) {
    return (getActiveRepositories().account as any)[prop];
  },
});

export const checkoutRepository = new Proxy({} as typeof backendCheckoutRepository, {
  get(_target, prop) {
    return (getActiveRepositories().checkout as any)[prop];
  },
});

export const sellerRepository = new Proxy({} as typeof backendSellerRepository, {
  get(_target, prop) {
    return (getActiveRepositories().seller as any)[prop];
  },
});

export const returnsRepository = new Proxy({} as typeof backendReturnsRepository, {
  get(_target, prop) {
    return (getActiveRepositories().returns as any)[prop];
  },
});

export const adminRepository = new Proxy({} as typeof backendAdminRepository, {
  get(_target, prop) {
    return (getActiveRepositories().admin as any)[prop];
  },
});

export const repositories = {
  get catalog() {
    return getActiveRepositories().catalog;
  },
  get cart() {
    return getActiveRepositories().cart;
  },
  get wishlist() {
    return getActiveRepositories().wishlist;
  },
  get account() {
    return getActiveRepositories().account;
  },
  get checkout() {
    return getActiveRepositories().checkout;
  },
  get seller() {
    return getActiveRepositories().seller;
  },
  get returns() {
    return getActiveRepositories().returns;
  },
  get admin() {
    return getActiveRepositories().admin;
  },
};
