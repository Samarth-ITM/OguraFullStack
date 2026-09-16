import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Ogura — Coming Soon" },
      { name: "description", content: "Ogura is a new project coming soon." },
      { property: "og:title", content: "Ogura — Coming Soon" },
      { property: "og:description", content: "Ogura is a new project coming soon." },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-background px-6 text-center">
      <h1 className="text-4xl font-semibold tracking-tight text-foreground sm:text-5xl">
        Ogura
      </h1>
      <p className="mt-3 max-w-sm text-base text-muted-foreground">
        A simple, focused place on the web.
      </p>
      <span className="mt-8 inline-flex items-center rounded-full border border-border bg-card px-4 py-1.5 text-sm font-medium text-card-foreground">
        Coming soon
      </span>
    </main>
  );
}
