import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/returns")({
  head: () => ({
    meta: [
      { title: "Returns & exchanges — OGURA" },
      { name: "description", content: "A simple 7-day window on ready-to-ship pieces, with exchanges wherever stock allows." },
      { property: "og:title", content: "Returns & exchanges — OGURA" },
      { property: "og:description", content: "A simple 7-day window on ready-to-ship pieces, with exchanges wherever stock allows." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Eligibility",
    "body": "Unworn pieces with tags intact, within 7 days of delivery."
  },
  {
    "heading": "Made to order",
    "body": "Custom-crafted and altered pieces are final sale."
  },
  {
    "heading": "Refunds",
    "body": "Processed to the original payment method within 5 to 7 working days."
  },
  {
    "heading": "Exchanges",
    "body": "Free size exchange once per order, subject to availability."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Returns"
      title="Returns & exchanges"
      intro="A simple 7-day window on ready-to-ship pieces, with exchanges wherever stock allows."
      sections={SECTIONS}
    />
  );
}
