import { useEffect, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { toast } from "sonner";
import { signIn, signOut, useOguraState } from "@/state/store";
import { accountRepository } from "@/repositories";
import { supabase } from "@/lib/supabase";
import { lovable } from "@/integrations/lovable";
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

function normalisePhone(input: string): string | null {
  const digits = input.replace(/\D/g, "");
  if (input.trim().startsWith("+") && digits.length >= 10) return `+${digits}`;
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length > 10) return `+${digits}`;
  return null;
}

function ProfilePage() {
  const profile = useOguraState((s) => s.profile);
  const [form, setForm] = useState({ name: profile.name, email: profile.email, phone: profile.phone });
  const [phoneInput, setPhoneInput] = useState("");
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

  const DEMO_OTP = "123456";
  const [demoMode, setDemoMode] = useState(false);

  const handleRequestOtp = async () => {
    const phone = normalisePhone(phoneInput);
    if (!phone) {
      setAuthError("Enter a valid mobile number.");
      return;
    }
    setLoading(true);
    setAuthError("");

    const res = await supabase.auth.signInWithOtp({ phone });
    if (res.error) {
      // No live SMS provider — fall back to a clearly-labelled demo code.
      setDemoMode(true);
      setOtpSent(true);
      toast.success(`Demo code: ${DEMO_OTP}`, { description: "Simulated SMS — no real message sent." });
      setLoading(false);
      return;
    }
    setDemoMode(false);
    setOtpSent(true);
    toast.success("Verification code sent");
    setLoading(false);
  };

  const handleVerifyOtp = async () => {
    const phone = normalisePhone(phoneInput);
    if (!phone) {
      setAuthError("Enter a valid mobile number.");
      return;
    }
    if (!otpCode || otpCode.length < 6) {
      setAuthError("Enter the 6-digit code.");
      return;
    }
    setLoading(true);
    setAuthError("");

    if (demoMode) {
      if (otpCode !== DEMO_OTP) {
        setAuthError("Incorrect demo code.");
        setLoading(false);
        return;
      }
      signIn({ ...form, phone, signedIn: true });
      toast.success("Signed in (demo)", { description: "Simulated sign-in — not a real account session." });
      setOtpSent(false);
      setOtpCode("");
      setLoading(false);
      return;
    }

    const res = await supabase.auth.verifyOtp({ phone, token: otpCode, type: "sms" });
    if (res.error) {
      setAuthError(res.error.message);
      setLoading(false);
      return;
    }
    toast.success("Signed in successfully");
    setOtpSent(false);
    setOtpCode("");
    setLoading(false);
  };


  const handleGoogleSignIn = async () => {
    setLoading(true);
    setAuthError("");
    try {
      const result = await lovable.auth.signInWithOAuth("google", {
        redirect_uri: typeof window !== "undefined" ? window.location.origin : "",
      });
      if (result.error) {
        setAuthError(result.error.message || "Google sign-in failed.");
        setLoading(false);
        return;
      }
      if (result.redirected) return;
      if (result.tokens?.access_token) {
        supabase.auth.setSessionFromTokens(result.tokens);
        toast.success("Signed in with Google");
      }
    } catch (err) {
      setAuthError(err instanceof Error ? err.message : "Google sign-in failed.");
    }
    setLoading(false);
  };

  return (
    <div className="max-w-md space-y-5">
      <p className="text-sm text-secondary-text">
        {profile.signedIn
          ? "Your verified OGURA account details."
          : "Continue with Google or your mobile number to access your orders, saved bag, and addresses."}
      </p>

      {profile.signedIn ? (
        <>
          <OgInput
            placeholder="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          {profile.email ? (
            <p className="text-xs text-secondary-text">Email · {profile.email}</p>
          ) : (
            <OgInput
              placeholder="Email"
              type="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          )}
          {profile.phone ? (
            <p className="text-xs text-secondary-text">Mobile · {profile.phone}</p>
          ) : (
            <OgInput
              placeholder="Mobile number"
              inputMode="tel"
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
            />
          )}
          <div className="flex flex-wrap gap-3">
            <OgButton onClick={handleSaveProfile} disabled={loading}>
              {loading ? "Saving…" : "Save details"}
            </OgButton>
            <OgButton
              variant="secondary"
              onClick={() => {
                signOut();
                setForm({ name: "", email: "", phone: "" });
                setPhoneInput("");
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
              <OgButton
                type="button"
                variant="secondary"
                onClick={handleGoogleSignIn}
                disabled={loading}
                className="w-full"
              >
                Continue with Google
              </OgButton>
              <div className="relative my-3 flex items-center justify-center">
                <div className="border-border absolute inset-0 flex items-center">
                  <div className="border-border w-full border-t" />
                </div>
                <div className="bg-background relative px-3 text-xs uppercase tracking-widest text-secondary-text">
                  Or
                </div>
              </div>
              <OgInput
                placeholder="Mobile number"
                inputMode="tel"
                value={phoneInput}
                onChange={(e) => setPhoneInput(e.target.value)}
              />
              {authError ? (
                <p role="alert" className="text-xs text-error">
                  {authError}
                </p>
              ) : null}
              <OgButton onClick={handleRequestOtp} disabled={loading}>
                {loading ? "Sending code…" : "Send verification code"}
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
                  Change number
                </OgButton>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
