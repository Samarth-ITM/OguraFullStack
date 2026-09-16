import { createFileRoute } from "@tanstack/react-router";
import { PlpEngine } from "@/components/plp/PlpEngine";

export const Route = createFileRoute("/made-to-order")({
  head: () => ({
    meta: [
      { title: "Made to Order — OGURA" },
      { name: "description", content: "Pieces crafted after you order, in your measurements, by independent Indian designers." },
      { property: "og:title", content: "Made to Order — OGURA" },
      { property: "og:description", content: "Crafted after you order, in your measurements." },
    ],
  }),
  component: MadeToOrderPage,
});

function MadeToOrderPage() {
  return (
    <PlpEngine
      title="Made to Order"
      crumbs={[{ label: "Home", to: "/" }, { label: "Made to Order" }]}
      baseQuery={{ madeToOrder: true }}
      templateKey="shop"
    />
  );
}
