import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/about")({
  head: () => ({
    meta: [
      { title: "About OGURA — OGURA" },
      { name: "description", content: "OGURA is a curated marketplace for independent Indian designers — considered pieces, honestly priced." },
      { property: "og:title", content: "About OGURA — OGURA" },
      { property: "og:description", content: "OGURA is a curated marketplace for independent Indian designers — considered pieces, honestly priced." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Our point of view",
    "body": "Fashion that defines you: fewer, better pieces from labels with something to say."
  },
  {
    "heading": "Curation",
    "body": "Every label is reviewed for craft, consistency and originality before it joins."
  },
  {
    "heading": "Pricing",
    "body": "Our range spans ₹1,111 to ₹15,000, with most of the edit under ₹3,000."
  },
  {
    "heading": "This build",
    "body": "A frontend prototype: all catalogue data is generated and all imagery is a placeholder."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="About"
      title="About OGURA"
      intro="OGURA is a curated marketplace for independent Indian designers — considered pieces, honestly priced."
      sections={SECTIONS}
    />
  );
}
