export interface NavLink {
  label: string;
  to: string;
}

export const PRIMARY_NAV: NavLink[] = [
  { label: "SHOP", to: "/shop" },
  { label: "BRANDS", to: "/brands" },
  { label: "DESIGNERS", to: "/designers" },
  { label: "OCCASIONS", to: "/occasions" },
  { label: "MADE TO ORDER", to: "/made-to-order" },
];

export const SHOP_BY_PRICE: NavLink[] = [
  { label: "Under ₹2,000", to: "/collections/under-2000" },
  { label: "Under ₹3,000", to: "/collections/under-3000" },
  { label: "₹3,000 – ₹4,999", to: "/collections/3000-to-4999" },
  { label: "₹5,000 – ₹9,999", to: "/collections/5000-to-9999" },
  { label: "₹10,000 – ₹15,000", to: "/collections/10000-to-15000" },
];

export const FOOTER_COLUMNS: { title: string; links: NavLink[] }[] = [
  {
    title: "Shop",
    links: [
      { label: "All Shop", to: "/shop" },
      { label: "New In", to: "/new-in" },
      { label: "Clothing", to: "/women/clothing" },
      { label: "Ethnicwear", to: "/women/ethnicwear" },
      { label: "Footwear", to: "/women/footwear" },
      { label: "Accessories", to: "/women/accessories" },
    ],
  },
  {
    title: "Discover",
    links: [
      { label: "Brands", to: "/brands" },
      { label: "Designers", to: "/designers" },
      { label: "Occasions", to: "/occasions" },
      { label: "Launchpad", to: "/launchpad" },
      { label: "Made to Order", to: "/made-to-order" },
      { label: "Gift Card", to: "/gift-card" },
    ],
  },
  {
    title: "Help",
    links: [
      { label: "Help Centre", to: "/help" },
      { label: "Contact", to: "/contact" },
      { label: "Shipping", to: "/shipping" },
      { label: "Returns", to: "/returns" },
      { label: "Track Order", to: "/track-order" },
      { label: "Stores", to: "/stores" },
    ],
  },
  {
    title: "About",
    links: [
      { label: "Join as Designer", to: "/join-as-designer" },
      { label: "Seller Program", to: "/seller-program" },
      { label: "Careers", to: "/careers" },
      { label: "Privacy", to: "/privacy" },
      { label: "Terms", to: "/terms" },
    ],
  },
];

export const SOCIAL_LINKS: NavLink[] = [
  { label: "Instagram", to: "/contact" },
  { label: "Pinterest", to: "/contact" },
  { label: "YouTube", to: "/contact" },
];

export const MOBILE_BOTTOM_NAV: NavLink[] = [
  { label: "Home", to: "/" },
  { label: "Explore", to: "/shop" },
  { label: "Wishlist", to: "/wishlist" },
  { label: "Bag", to: "/cart" },
  { label: "Account", to: "/account" },
];
