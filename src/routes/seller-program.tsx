import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/seller-program")({
  head: () => ({
    meta: [
      { title: "Seller programme — OGURA" },
      { name: "description", content: "Tools, terms and support for labels selling on OGURA." },
      { property: "og:title", content: "Seller programme — OGURA" },
      { property: "og:description", content: "Tools, terms and support for labels selling on OGURA." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Onboarding",
    "body": "Catalogue setup, taxonomy mapping and imagery review in under two weeks."
  },
  {
    "heading": "Studio",
    "body": "A seller workspace for products, orders and payouts."
  },
  {
    "heading": "Payouts",
    "body": "Fortnightly cycles on the 1st and 15th."
  },
  {
    "heading": "Support",
    "body": "A named partnerships manager for every label."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Sellers"
      title="Seller programme"
      intro="Tools, terms and support for labels selling on OGURA."
      sections={SECTIONS}
    />
  );
}
