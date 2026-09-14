import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { FOOTER_COLUMNS, SOCIAL_LINKS } from "@/config/navigation";
import { Eyebrow, OgButton, OgInput } from "@/components/ui-og/primitives";

export function Footer() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "ok" | "error">("idle");

  return (
    <footer className="mt-24 border-t border-border bg-deep">
      <div className="container-og py-16">
        <div className="mx-auto max-w-2xl text-center">
          <Eyebrow>Newsletter</Eyebrow>
          <h2 className="display-h2 mt-4 text-foreground">New labels, first</h2>
          <p className="mt-3 text-sm text-secondary-text">
            One email when a new designer joins OGURA. Sign-up is simulated locally in this prototype.
          </p>
          <form
            className="mt-6 flex flex-col gap-3 sm:flex-row"
            onSubmit={(e) => {
              e.preventDefault();
              setStatus(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? "ok" : "error");
            }}
          >
            <label className="sr-only" htmlFor="newsletter-email">
              Email address
            </label>
            <OgInput
              id="newsletter-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Your email address"
              aria-describedby="newsletter-status"
            />
            <OgButton type="submit" className="sm:w-56">
              Join the list
            </OgButton>
          </form>
          <p id="newsletter-status" className="mt-3 min-h-5 text-xs" aria-live="polite">
            {status === "ok" ? (
              <span className="text-success">Saved locally — no email was sent in this prototype.</span>
            ) : null}
            {status === "error" ? <span className="text-error">Enter a valid email address.</span> : null}
          </p>
        </div>

        <div className="mt-16 grid gap-10 border-t border-border pt-12 sm:grid-cols-2 lg:grid-cols-5">
          {FOOTER_COLUMNS.map((col) => (
            <nav key={col.title} aria-label={col.title}>
              <Eyebrow className="mb-4">{col.title}</Eyebrow>
              <ul className="space-y-2.5">
                {col.links.map((link) => (
                  <li key={link.to + link.label}>
                    <Link to={link.to} className="text-sm text-secondary-text transition-colors hover:text-foreground">
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
          <div>
            <Eyebrow className="mb-4">Follow</Eyebrow>
            <ul className="space-y-2.5">
              {SOCIAL_LINKS.map((link) => (
                <li key={link.label}>
                  <Link to={link.to} className="text-sm text-secondary-text transition-colors hover:text-foreground">
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="mt-12 flex flex-col gap-3 border-t border-border pt-8 text-xs text-muted-text sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} OGURA. Frontend prototype — catalog and prices are mock data.</p>
          <div className="flex gap-5">
            <Link to="/privacy" className="hover:text-foreground">
              Privacy
            </Link>
            <Link to="/terms" className="hover:text-foreground">
              Terms
            </Link>
            <Link to="/contact" className="hover:text-foreground">
              Contact
            </Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
