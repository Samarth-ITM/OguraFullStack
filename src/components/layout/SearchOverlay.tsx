import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate } from "@tanstack/react-router";
import { X } from "lucide-react";
import { catalogRepository } from "@/repositories";
import { generatedBrands } from "@/data/generated/brands";
import { CATEGORIES } from "@/data/taxonomy";
import type { Product } from "@/domain/catalog";
import { useUi, useFocusTrap } from "@/state/ui";
import { clearSearchHistory, pushSearchHistory, useOguraState } from "@/state/store";
import { Eyebrow, OgInput } from "@/components/ui-og/primitives";
import { formatINR } from "@/lib/format";

export function SearchOverlay() {
  const { searchOpen, closeSearch } = useUi();
  const [term, setTerm] = useState("");
  const [results, setResults] = useState<Product[]>([]);
  const [status, setStatus] = useState<"idle" | "typing" | "loading" | "ready" | "error">("idle");
  const history = useOguraState((s) => s.searchHistory);
  const navigate = useNavigate();
  const inputRef = useRef<HTMLInputElement>(null);
  const trapRef = useFocusTrap(searchOpen, closeSearch);

  useEffect(() => {
    if (!searchOpen) {
      setTerm("");
      setResults([]);
      setStatus("idle");
    } else {
      window.setTimeout(() => inputRef.current?.focus(), 30);
    }
  }, [searchOpen]);

  useEffect(() => {
    if (!term.trim()) {
      setResults([]);
      setStatus("idle");
      return;
    }
    setStatus("typing");
    const id = window.setTimeout(() => {
      setStatus("loading");
      catalogRepository
        .searchProducts(term, 6)
        .then((items) => {
          setResults(items);
          setStatus("ready");
        })
        .catch(() => setStatus("error"));
    }, 220);
    return () => window.clearTimeout(id);
  }, [term]);

  const brandMatches = useMemo(
    () =>
      term.trim()
        ? generatedBrands.filter((b) => b.name.toLowerCase().includes(term.toLowerCase())).slice(0, 4)
        : [],
    [term],
  );
  const categoryMatches = useMemo(
    () =>
      term.trim()
        ? CATEGORIES.flatMap((c) => [
            { slug: `/women/${c.slug}`, name: c.name },
            ...c.children.map((ch) => ({ slug: `/women/${c.slug}/${ch.slug}`, name: ch.name })),
          ]).filter((c) => c.name.toLowerCase().includes(term.toLowerCase())).slice(0, 4)
        : [],
    [term],
  );

  if (!searchOpen) return null;

  const submit = () => {
    if (!term.trim()) return;
    pushSearchHistory(term.trim());
    closeSearch();
    navigate({ to: "/search", search: { q: term.trim() } as never });
  };

  return (
    <div className="fixed inset-0 z-[70] bg-deep/95 backdrop-blur-sm" role="dialog" aria-modal="true" aria-label="Search">
      <div ref={trapRef} className="container-og flex h-full flex-col py-6 sm:py-10">
        <div className="flex items-center gap-4">
          <form
            className="flex-1"
            onSubmit={(e) => {
              e.preventDefault();
              submit();
            }}
          >
            <label className="sr-only" htmlFor="og-search">
              Search
            </label>
            <OgInput
              id="og-search"
              ref={inputRef}
              value={term}
              onChange={(e) => setTerm(e.target.value)}
              placeholder="Search products, designers & looks"
              className="h-14 min-h-14 rounded-none border-0 border-b border-border-strong bg-transparent px-0 font-display text-2xl"
            />
          </form>
          <button
            type="button"
            onClick={closeSearch}
            aria-label="Close search"
            className="grid size-11 place-items-center text-secondary-text hover:text-foreground"
          >
            <X className="size-5" />
          </button>
        </div>

        <div className="mt-8 flex-1 overflow-y-auto" aria-live="polite">
          {status === "idle" ? (
            <div className="grid gap-10 sm:grid-cols-2">
              <div>
                <div className="mb-4 flex items-center justify-between">
                  <Eyebrow>Recent searches</Eyebrow>
                  {history.length ? (
                    <button type="button" onClick={clearSearchHistory} className="text-xs text-muted-text hover:text-foreground">
                      Clear
                    </button>
                  ) : null}
                </div>
                {history.length ? (
                  <ul className="space-y-2">
                    {history.map((h) => (
                      <li key={h}>
                        <button
                          type="button"
                          className="text-sm text-secondary-text hover:text-foreground"
                          onClick={() => setTerm(h)}
                        >
                          {h}
                        </button>
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-sm text-muted-text">Your recent searches will appear here.</p>
                )}
              </div>
              <div>
                <Eyebrow className="mb-4">Popular</Eyebrow>
                <ul className="space-y-2">
                  {["Corset tops", "Co-ord sets", "Lehengas", "Under ₹3,000", "Made to order"].map((s) => (
                    <li key={s}>
                      <button type="button" className="text-sm text-secondary-text hover:text-foreground" onClick={() => setTerm(s)}>
                        {s}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ) : null}

          {status === "typing" || status === "loading" ? (
            <p className="text-sm text-muted-text">Searching…</p>
          ) : null}

          {status === "error" ? <p className="text-sm text-error">Search is unavailable right now.</p> : null}

          {status === "ready" ? (
            results.length || brandMatches.length || categoryMatches.length ? (
              <div className="grid gap-10 lg:grid-cols-[2fr_1fr]">
                <div>
                  <Eyebrow className="mb-4">Products</Eyebrow>
                  <ul className="space-y-3">
                    {results.map((p) => (
                      <li key={p.id}>
                        <Link
                          to="/product/$productSlug"
                          params={{ productSlug: p.slug }}
                          onClick={closeSearch}
                          className="flex items-baseline justify-between gap-4 border-b border-border pb-3 hover:text-rose"
                        >
                          <span className="min-w-0">
                            <span className="block truncate text-sm">{p.title}</span>
                            <span className="block text-xs text-muted-text">{p.brandName}</span>
                          </span>
                          <span className="shrink-0 text-sm">{formatINR(p.price)}</span>
                        </Link>
                      </li>
                    ))}
                    {!results.length ? <li className="text-sm text-muted-text">No product matches.</li> : null}
                  </ul>
                  <button type="button" onClick={submit} className="mt-6 text-xs uppercase tracking-[0.18em] text-rose">
                    See all results for “{term}”
                  </button>
                </div>
                <div className="space-y-8">
                  {brandMatches.length ? (
                    <div>
                      <Eyebrow className="mb-4">Brands & designers</Eyebrow>
                      <ul className="space-y-2">
                        {brandMatches.map((b) => (
                          <li key={b.slug}>
                            <Link
                              to="/brand/$brandSlug"
                              params={{ brandSlug: b.slug }}
                              onClick={closeSearch}
                              className="text-sm text-secondary-text hover:text-foreground"
                            >
                              {b.name}
                            </Link>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ) : null}
                  {categoryMatches.length ? (
                    <div>
                      <Eyebrow className="mb-4">Categories</Eyebrow>
                      <ul className="space-y-2">
                        {categoryMatches.map((c) => (
                          <li key={c.slug}>
                            <Link to={c.slug} onClick={closeSearch} className="text-sm text-secondary-text hover:text-foreground">
                              {c.name}
                            </Link>
                          </li>
                        ))}
                      </ul>
                    </div>
                  ) : null}
                </div>
              </div>
            ) : (
              <div className="max-w-md">
                <p className="font-display text-2xl">No results for “{term}”</p>
                <p className="mt-2 text-sm text-secondary-text">
                  Try a shorter term, a designer name, or browse the full edit.
                </p>
                <Link to="/shop" onClick={closeSearch} className="mt-4 inline-block text-xs uppercase tracking-[0.18em] text-rose">
                  Browse all styles
                </Link>
              </div>
            )
          ) : null}
        </div>
      </div>
    </div>
  );
}
