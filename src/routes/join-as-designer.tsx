import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/join-as-designer")({
  head: () => ({
    meta: [
      { title: "Join as a designer — OGURA" },
      { name: "description", content: "OGURA partners with independent Indian labels who make in small, considered runs." },
      { property: "og:title", content: "Join as a designer — OGURA" },
      { property: "og:description", content: "OGURA partners with independent Indian labels who make in small, considered runs." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Who we look for",
    "body": "Labels with a clear point of view, consistent quality and honest production."
  },
  {
    "heading": "What we handle",
    "body": "Merchandising, photography guidance, payments and delivery logistics."
  },
  {
    "heading": "Commission",
    "body": "Transparent tiered commission with fortnightly payouts."
  },
  {
    "heading": "Apply",
    "body": "Share your lookbook through the contact page to start a conversation."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Designers"
      title="Join as a designer"
      intro="OGURA partners with independent Indian labels who make in small, considered runs."
      sections={SECTIONS}
    />
  );
}
