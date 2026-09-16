import { useEffect, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { toast } from "sonner";
import { signIn, signOut, useOguraState } from "@/state/store";
import { accountRepository } from "@/repositories";
import { supabase } from "@/lib/supabase";
import { OgButton, OgInput } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account/profile")({
  head: () => ({
    meta: [
      { title: "Profile — OGURA" },
      { name: "description", content: "Your profile details on OGURA." },
      { property: "og:title", content: "Profile — OGURA" },
      { property: "og:description", content: "Your profile details." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ProfilePage,
});

function ProfilePage() {
  const profile = useOguraState((s) => s.profile);
  const [form, setForm] = useState({ name: profile.name, email: profile.email, phone: profile.phone });
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    setForm({ name: profile.name, email: profile.email, phone: profile.phone });
  }, [profile.name, profile.email, profile.phone]);

  const handleSaveProfile = async () => {
    setLoading(true);
    try {
      await accountRepository.updateProfile(form);
      signIn({ ...form, signedIn: true });
      toast.success("Profile updated successfully");
    } catch {
      toast.error("Failed to update profile");
    } finally {
      setLoading(false);
    }
  };

  const handleRequestOtp = async () => {
    if (!form.phone && !form.email) {
      setAuthError("Enter a mobile number or email address.");
      return;
    }
    setLoading(true);
    setAuthError("");

    if (supabase.isConfigured()) {
      const res = await supabase.auth.signInWithOtp(
        form.phone ? { phone: form.phone } : { email: form.email },
      );
      if (res.error) {
        setAuthError(res.error.message);
        setLoading(false);
        return;
      }
      setOtpSent(true);
      toast.success("Verification code sent");
      toast("Sample test code: 123456", { description: "Demo only — for testing the sign-in screen." });
      setLoading(false);
    } else {
      // Offline / Dev mode fallback
      setOtpSent(true);
      toast("Sample test code: 123456", { description: "Demo only — for testing the sign-in screen." });
      setLoading(false);
    }
  };

  const handleVerifyOtp = async () => {
    if (!otpCode || otpCode.length < 6) {
      setAuthError("Enter the 6-digit code.");
      return;
    }
    setLoading(true);
    setAuthError("");

    if (supabase.isConfigured()) {
      const verifyParams: { phone?: string; email?: string; token: string; type?: "sms" | "email" } = {
        token: otpCode,
        type: form.phone ? "sms" : "email",
      };
      if (form.phone) verifyParams.phone = form.phone;
      if (form.email) verifyParams.email = form.email;

      const res = await supabase.auth.verifyOtp(verifyParams);
      if (res.error) {
        setAuthError(res.error.message);
        setLoading(false);
        return;
      }
      toast.success("Signed in successfully");
      setOtpSent(false);
      setOtpCode("");
      setLoading(false);
    } else {
      signIn({ ...form, signedIn: true });
      toast.success("Signed in (demo mode)");
      setOtpSent(false);
      setOtpCode("");
      setLoading(false);
    }
  };

  const handleGoogleSignIn = async () => {
    setLoading(true);
    setAuthError("");
    if (supabase.isConfigured()) {
      const res = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: typeof window !== "undefined" ? `${window.location.origin}/account/profile` : undefined,
        },
      });
      if (res.error) {
        setAuthError(res.error.message);
        setLoading(false);
      }
    } else {
      signIn({ name: "Demo User", email: "user@example.com", phone: "", signedIn: true });
      toast.success("Signed in with Google (demo mode)");
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md space-y-5">
      <p className="text-sm text-secondary-text">
        {profile.signedIn
          ? "Your verified OGURA account details."
          : "Sign in with your mobile number or email to access your orders, saved bag, and addresses."}
      </p>

      {profile.signedIn ? (
        <>
          <OgInput
            placeholder="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <OgInput
            placeholder="Email"
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
          <OgInput
            placeholder="Phone"
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
          />
          <div className="flex flex-wrap gap-3">
            <OgButton onClick={handleSaveProfile} disabled={loading}>
              {loading ? "Saving…" : "Save details"}
            </OgButton>
            <OgButton
              variant="secondary"
              onClick={() => {
                signOut();
                setForm({ name: "", email: "", phone: "" });
                setOtpSent(false);
                toast("Signed out");
              }}
            >
              Sign out
            </OgButton>
          </div>
        </>
      ) : (
        <>
          {!otpSent ? (
            <>
              <OgInput
                placeholder="Mobile number or email"
                value={form.phone || form.email}
                onChange={(e) => {
                  const val = e.target.value;
                  if (val.includes("@")) {
                    setForm({ ...form, email: val, phone: "" });
                  } else {
                    setForm({ ...form, phone: val, email: "" });
                  }
                }}
              />
              {authError ? (
                <p role="alert" className="text-xs text-error">
                  {authError}
                </p>
              ) : null}
              <OgButton onClick={handleRequestOtp} disabled={loading}>
                {loading ? "Sending code…" : "Send verification code"}
              </OgButton>
              <div className="relative my-3 flex items-center justify-center">
                <div className="border-border absolute inset-0 flex items-center">
                  <div className="border-border w-full border-t" />
                </div>
                <div className="bg-background relative px-3 text-xs uppercase tracking-widest text-secondary-text">
                  Or
                </div>
              </div>
              <OgButton
                type="button"
                variant="secondary"
                onClick={handleGoogleSignIn}
                disabled={loading}
                className="w-full"
              >
                Continue with Google
              </OgButton>
            </>
          ) : (
            <>
              <OgInput
                placeholder="Enter 6-digit code"
                inputMode="numeric"
                value={otpCode}
                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
              />
              {authError ? (
                <p role="alert" className="text-xs text-error">
                  {authError}
                </p>
              ) : null}
              <div className="flex flex-wrap gap-3">
                <OgButton onClick={handleVerifyOtp} disabled={loading}>
                  {loading ? "Verifying…" : "Verify & sign in"}
                </OgButton>
                <OgButton
                  variant="secondary"
                  onClick={() => {
                    setOtpSent(false);
                    setAuthError("");
                  }}
                >
                  Change number/email
                </OgButton>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
