import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/help")({
  head: () => ({
    meta: [
      { title: "Help Centre — OGURA" },
      { name: "description", content: "Answers to the questions we hear most often about ordering, sizing, delivery and returns on OGURA." },
      { property: "og:title", content: "Help Centre — OGURA" },
      { property: "og:description", content: "Answers to the questions we hear most often about ordering, sizing, delivery and returns on OGURA." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Orders",
    "body": "Track any prototype order from your account. Real orders are not processed in this demo build."
  },
  {
    "heading": "Sizing",
    "body": "Every product page carries a size and fit note written with the designer, plus a measurement guide."
  },
  {
    "heading": "Payments",
    "body": "Card, UPI and cash on delivery are shown as mock options. No payment is collected."
  },
  {
    "heading": "Still stuck?",
    "body": "Use the contact page and a member of the OGURA team will reply within one working day."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Help centre"
      title="Help Centre"
      intro="Answers to the questions we hear most often about ordering, sizing, delivery and returns on OGURA."
      sections={SECTIONS}
    />
  );
}
