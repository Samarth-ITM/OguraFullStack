import { createFileRoute } from "@tanstack/react-router";
import { PlpEngine } from "@/components/plp/PlpEngine";

export const Route = createFileRoute("/shop")({
  head: () => ({
    meta: [
      { title: "Shop all — OGURA" },
      { name: "description", content: "All 311 design-led styles on OGURA: clothing, ethnicwear, footwear and accessories." },
      { property: "og:title", content: "Shop all — OGURA" },
      { property: "og:description", content: "Browse the full OGURA selection from independent designers." },
    ],
  }),
  component: ShopPage,
});

function ShopPage() {
  return (
    <PlpEngine
      title="The OGURA Selection"
      description="Every style in the prototype catalogue"
      crumbs={[{ label: "Home", to: "/" }, { label: "Shop" }]}
      baseQuery={{}}
      templateKey="shop"
    />
  );
}
