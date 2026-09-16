import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/track-order")({
  head: () => ({
    meta: [
      { title: "Track your order — OGURA" },
      { name: "description", content: "Enter an order number to see its status. Prototype orders you place are stored only in this browser." },
      { property: "og:title", content: "Track your order — OGURA" },
      { property: "og:description", content: "Enter an order number to see its status. Prototype orders you place are stored only in this browser." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Where to find it",
    "body": "Your order number looks like DEMO-OG-1234 and appears on the confirmation screen."
  },
  {
    "heading": "Status stages",
    "body": "Placed, packed, shipped and delivered."
  },
  {
    "heading": "Account",
    "body": "Signed-in prototype users can see every demo order under My OGURA."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Tracking"
      title="Track your order"
      intro="Enter an order number to see its status. Prototype orders you place are stored only in this browser."
      sections={SECTIONS}
    />
  );
}
