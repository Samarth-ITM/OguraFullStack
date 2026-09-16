import { useEffect, useMemo, useState } from "react";
import { createFileRoute, useNavigate } from "@tanstack/react-router";
import type { CheckoutDraft } from "@/domain/commerce";
import { productById, variantsByProduct } from "@/repositories/mock/catalog";
import { repositories, accountRepository } from "@/repositories";
import { supabase } from "@/lib/supabase";
import { EMPTY_DRAFT, clearCart, saveCheckoutDraft, saveOrder, setBuyNow, useOguraState } from "@/state/store";
import { formatINR } from "@/lib/format";
import { EmptyState, Eyebrow, OgButton, OgInput, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/checkout")({
  head: () => ({
    meta: [
      { title: "Checkout — OGURA" },
      { name: "description", content: "Prototype checkout — no payment is processed." },
      { property: "og:title", content: "Checkout — OGURA" },
      { property: "og:description", content: "Complete your prototype order." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CheckoutPage,
});

const STEPS = ["Contact", "Address", "Delivery", "Payment", "Review"] as const;

function CheckoutPage() {
  const navigate = useNavigate();
  const cartLines = useOguraState((s) => s.cart.lines);
  const buyNow = useOguraState((s) => s.buyNow);
  const storedDraft = useOguraState((s) => s.checkoutDraft);

  const [step, setStep] = useState(0);
  const [draft, setDraft] = useState<CheckoutDraft>(storedDraft ?? EMPTY_DRAFT);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [placing, setPlacing] = useState(false);
  const [quote, setQuote] = useState<import("@/repositories/contracts").AuthoritativeQuote | null>(null);
  const [quoteError, setQuoteError] = useState<string | null>(null);
  const requiresAuth = supabase.isConfigured();
  const [authed, setAuthed] = useState(!requiresAuth);

  useEffect(() => {
    if (!requiresAuth) return;
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (active) setAuthed(Boolean(data.session?.access_token));
    });
    return () => {
      active = false;
    };
  }, [requiresAuth]);

  const lines = buyNow ? [buyNow] : cartLines;
  const rows = useMemo(
    () =>
      lines.flatMap((line) => {
        const product = productById.get(line.productId);
        const variant = (variantsByProduct.get(line.productId) ?? []).find((v) => v.id === line.variantId);
        return product && variant ? [{ line, product, variant }] : [];
      }),
    [lines],
  );

  const fallbackSubtotal = rows.reduce((sum, r) => sum + r.variant.price * r.line.quantity, 0);
  const fallbackShipping = fallbackSubtotal >= 2999 ? 0 : draft.deliveryMethod === "express" ? 249 : 99;
  const subtotal = quote ? quote.subtotal : fallbackSubtotal;
  const shipping = quote ? quote.shipping : fallbackShipping;
  const total = quote ? quote.total : subtotal + shipping;

  if (rows.length === 0) {
    return (
      <div className="og-container py-20">
        <EmptyState
          title="Nothing to check out"
          body="Add a piece to your bag to continue."
          action={<OgLinkButton to="/shop">Shop all</OgLinkButton>}
        />
      </div>
    );
  }

  const set = (patch: Partial<CheckoutDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const setAddress = (patch: Partial<CheckoutDraft["address"]>) =>
    setDraft((d) => ({ ...d, address: { ...d.address, ...patch } }));

  const next = async () => {
    const found = await repositories.checkout.validateDraft(draft);
    const stepFields: Record<number, string[]> = {
      0: ["email", "phone"],
      1: ["fullName", "line1", "city", "state", "pincode"],
      2: [],
      3: [],
      4: [],
    };
    const allowed = stepFields[step] ?? [];
    const relevant: Record<string, string> = {};
    for (const [key, value] of Object.entries(found)) {
      if (allowed.includes(key)) relevant[key] = value;
    }
    setErrors(relevant);
    if (Object.keys(relevant).length) return;
    saveCheckoutDraft(draft);

    // Persist the delivery address to the customer account (existing repository contract)
    if (step === 1 && authed && accountRepository.saveAddress) {
      try {
        await accountRepository.saveAddress(draft.address);
      } catch {
        // Address persistence is best-effort; the authoritative quote still receives the address.
      }
    }

    // If moving to Delivery/Payment/Review, fetch authoritative server quote
    if (step >= 1 && repositories.checkout.createAuthoritativeQuote) {
      try {
        const customAddr = {
          full_name: draft.address.fullName,
          phone: draft.phone,
          line1: draft.address.line1,
          line2: draft.address.line2 || "",
          city: draft.address.city,
          state: draft.address.state,
          pincode: draft.address.pincode,
          country: "India",
        };
        const serverQuote = await repositories.checkout.createAuthoritativeQuote(undefined, customAddr);
        setQuote(serverQuote);
        setQuoteError(null);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : "Failed to obtain server quote.";
        setQuoteError(message);
      }
    }

    setStep((s) => Math.min(STEPS.length - 1, s + 1));
  };

  const placeOrder = async () => {
    if (requiresAuth && !authed) {
      setQuoteError("Please sign in to complete your purchase.");
      return;
    }
    const found = await repositories.checkout.validateDraft(draft);
    if (Object.keys(found).length) {
      setErrors(found);
      setStep(0);
      return;
    }
    setPlacing(true);
    setQuoteError(null);

    try {
      if (repositories.checkout.createAuthoritativeQuote && repositories.checkout.createOrderFromQuote) {
        const customAddr = {
          full_name: draft.address.fullName,
          phone: draft.phone,
          line1: draft.address.line1,
          line2: draft.address.line2 || "",
          city: draft.address.city,
          state: draft.address.state,
          pincode: draft.address.pincode,
          country: "India",
        };
        const serverQuote = await repositories.checkout.createAuthoritativeQuote(undefined, customAddr);
        const serverOrder = await repositories.checkout.createOrderFromQuote(serverQuote.quoteId);

        if (buyNow) setBuyNow(null);
        else clearCart();

        saveOrder({
          orderNumber: serverOrder.orderNumber,
          createdAt: Date.now(),
          status: "placed",
          items: rows.map((r) => ({
            productId: r.product.id,
            variantId: r.variant.id,
            title: r.product.title,
            brandName: r.product.brandName,
            size: r.variant.size,
            color: r.variant.color,
            quantity: r.line.quantity,
            price: r.variant.price,
          })),
          subtotal: serverQuote.subtotal,
          shipping: serverQuote.shipping,
          total: serverOrder.total,
          address: draft.address,
          paymentMethod: draft.paymentMethod,
          prototype: true,
        });

        setPlacing(false);
        navigate({ to: "/order/success/$orderId", params: { orderId: serverOrder.orderNumber } });
        return;
      }
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Order placement failed. Please verify your details.";
      setQuoteError(message);
      setPlacing(false);
      return;
    }

    const order = await repositories.checkout.createMockOrder(draft, draft.address);
    if (buyNow) setBuyNow(null);
    else clearCart();
    setPlacing(false);
    navigate({ to: "/order/success/$orderId", params: { orderId: order.orderNumber } });
  };

  const field = (name: string, label: string, value: string, onChange: (v: string) => void, extra?: object) => (
    <div>
      <label htmlFor={name} className="text-xs text-secondary-text">
        {label}
      </label>
      <OgInput
        id={name}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={Boolean(errors[name])}
        aria-describedby={errors[name] ? `${name}-error` : undefined}
        className="mt-1.5"
        {...extra}
      />
      {errors[name] ? (
        <p id={`${name}-error`} role="alert" className="mt-1 text-xs text-error">
          {errors[name]}
        </p>
      ) : null}
    </div>
  );

  return (
    <div className="og-container py-10 lg:py-16">
      <Eyebrow>Checkout</Eyebrow>
      <h1 className="mt-2 font-display text-4xl">Complete your order</h1>
      <p className="mt-2 text-sm text-warning">
        Prototype only — no payment is processed and no order is really placed.
      </p>

      <ol className="mt-8 flex flex-wrap gap-3 text-xs uppercase tracking-[0.14em]">
        {STEPS.map((label, i) => (
          <li key={label} className={i === step ? "text-rose" : i < step ? "text-foreground" : "text-muted-text"}>
            {i + 1}. {label}
          </li>
        ))}
      </ol>

      <div className="mt-10 grid gap-10 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="space-y-6">
          {step === 0 ? (
            <div className="space-y-5">
              {field("email", "Email", draft.email, (v) => set({ email: v }), { type: "email" })}
              {field("phone", "Mobile number", draft.phone, (v) => set({ phone: v }), { inputMode: "numeric" })}
            </div>
          ) : null}

          {step === 1 ? (
            <div className="grid gap-5 sm:grid-cols-2">
              {field("fullName", "Full name", draft.address.fullName, (v) => setAddress({ fullName: v }))}
              {field("line1", "Address line 1", draft.address.line1, (v) => setAddress({ line1: v }))}
              {field("line2", "Address line 2 (optional)", draft.address.line2, (v) => setAddress({ line2: v }))}
              {field("city", "City", draft.address.city, (v) => setAddress({ city: v }))}
              {field("state", "State", draft.address.state, (v) => setAddress({ state: v }))}
              {field("pincode", "Pincode", draft.address.pincode, (v) => setAddress({ pincode: v.replace(/\D/g, "").slice(0, 6) }), {
                inputMode: "numeric",
              })}
            </div>
          ) : null}

          {step === 2 ? (
            <fieldset className="space-y-3">
              <legend className="text-[11px] uppercase tracking-[0.18em]">Delivery method</legend>
              {[
                { value: "standard", label: "Standard — 4–7 days", price: subtotal >= 2999 ? "Free" : formatINR(99) },
                { value: "express", label: "Express — 2–4 days", price: subtotal >= 2999 ? "Free" : formatINR(249) },
              ].map((option) => (
                <label key={option.value} className="flex min-h-12 cursor-pointer items-center gap-3 border border-border px-4">
                  <input
                    type="radio"
                    name="delivery"
                    value={option.value}
                    checked={draft.deliveryMethod === option.value}
                    onChange={() => set({ deliveryMethod: option.value as CheckoutDraft["deliveryMethod"] })}
                    className="accent-[#E72D63]"
                  />
                  <span className="text-sm">{option.label}</span>
                  <span className="ml-auto text-sm text-secondary-text">{option.price}</span>
                </label>
              ))}
            </fieldset>
          ) : null}

          {step === 3 ? (
            <fieldset className="space-y-3">
              <legend className="text-[11px] uppercase tracking-[0.18em]">Payment method (mock)</legend>
              {[
                { value: "card", label: "Card" },
                { value: "upi", label: "UPI" },
                { value: "cod", label: "Cash on delivery" },
              ].map((option) => (
                <label key={option.value} className="flex min-h-12 cursor-pointer items-center gap-3 border border-border px-4">
                  <input
                    type="radio"
                    name="payment"
                    value={option.value}
                    checked={draft.paymentMethod === option.value}
                    onChange={() => set({ paymentMethod: option.value as CheckoutDraft["paymentMethod"] })}
                    className="accent-[#E72D63]"
                  />
                  <span className="text-sm">{option.label}</span>
                </label>
              ))}
              <p className="text-xs text-muted-text">No card details are collected in this prototype.</p>
            </fieldset>
          ) : null}

          {step === 4 ? (
            <div className="space-y-5 text-sm">
              <div className="border border-border p-4">
                <p className="text-[11px] uppercase tracking-[0.18em]">Contact</p>
                <p className="mt-2 text-secondary-text">
                  {draft.email} · {draft.phone}
                </p>
              </div>
              <div className="border border-border p-4">
                <p className="text-[11px] uppercase tracking-[0.18em]">Deliver to</p>
                <p className="mt-2 text-secondary-text">
                  {draft.address.fullName}, {draft.address.line1} {draft.address.line2}, {draft.address.city},{" "}
                  {draft.address.state} {draft.address.pincode}
                </p>
              </div>
              <div className="border border-border p-4">
                <p className="text-[11px] uppercase tracking-[0.18em]">Delivery & payment</p>
                <p className="mt-2 capitalize text-secondary-text">
                  {draft.deliveryMethod} · {draft.paymentMethod}
                </p>
              </div>
            </div>
          ) : null}

          {quoteError ? (
            <p role="alert" className="text-xs text-error">
              {quoteError}
            </p>
          ) : null}

          <div className="flex flex-wrap gap-3">
            {step > 0 ? (
              <OgButton variant="secondary" onClick={() => setStep((s) => s - 1)}>
                Back
              </OgButton>
            ) : null}
            {step < STEPS.length - 1 ? (
              <OgButton onClick={next}>Continue</OgButton>
            ) : (
              <OgButton onClick={placeOrder} disabled={placing}>
                {placing ? "Placing order…" : "Place prototype order"}
              </OgButton>
            )}
          </div>
        </div>

        <aside className="h-fit border border-border bg-surface p-6 lg:sticky lg:top-24">
          <h2 className="text-[11px] uppercase tracking-[0.18em]">Order summary</h2>
          <ul className="mt-5 space-y-3 text-sm">
            {rows.map(({ line, product, variant }) => (
              <li key={line.id} className="flex justify-between gap-3">
                <span className="min-w-0 text-secondary-text">
                  {product.title} <span className="text-muted-text">×{line.quantity}</span>
                </span>
                <span className="shrink-0">{formatINR(variant.price * line.quantity)}</span>
              </li>
            ))}
          </ul>
          <dl className="mt-5 space-y-2 border-t border-border pt-4 text-sm">
            <div className="flex justify-between">
              <dt className="text-secondary-text">Subtotal</dt>
              <dd>{formatINR(subtotal)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-secondary-text">Shipping</dt>
              <dd>{shipping === 0 ? "Free" : formatINR(shipping)}</dd>
            </div>
            <div className="flex justify-between border-t border-border pt-2 text-base">
              <dt>Total</dt>
              <dd>{formatINR(total)}</dd>
            </div>
          </dl>
        </aside>
      </div>
    </div>
  );
}
