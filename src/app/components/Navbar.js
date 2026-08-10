"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function Navbar() {
  const router = useRouter();

  const [loggedIn, setLoggedIn] = useState(false);
  const [fullName, setFullName] = useState("");

  async function loadSession() {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data?.user) {
      setLoggedIn(false);
      setFullName("");
      return;
    }

    setLoggedIn(true);

    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", data.user.id)
      .single();

    setFullName(profile?.full_name || "");
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    loadSession();
  }, []);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push("/");
  }

  return (
    <nav className="sticky top-0 z-50 h-[72px] bg-white flex items-center justify-between px-10 shadow-sm">
      <Link href="/" className="text-[22px] font-bold tracking-tight">
        ShapeRush
      </Link>

      <div className="hidden md:flex items-center gap-9 text-[13px] font-medium">
        <Link href="/#home">Home</Link>
        <Link href="/#features">Features</Link>
        <Link href="/#plans">Plans</Link>
        <Link href="/#reviews">Reviews</Link>
        <Link href="/#faq">FAQ</Link>
      </div>

      <div className="flex items-center gap-3">
        {loggedIn ? (
          <>
            <span className="text-[13px] font-semibold text-black px-2">
              {fullName}
            </span>
            <Link
              href="/welcome"
              className="text-[13px] font-semibold text-[#6c5cff] px-5 py-3"
            >
              Download
            </Link>
            <button
              type="button"
              onClick={handleLogout}
              className="bg-[#6c5cff] text-white px-8 py-3 rounded-xl text-[13px] font-semibold"
            >
              Logout
            </button>
          </>
        ) : (
          <>
            <Link
              href="/login"
              className="text-[13px] font-semibold text-[#6c5cff] px-5 py-3"
            >
              Login
            </Link>
            <Link
              href="/register"
              className="bg-[#6c5cff] text-white px-8 py-3 rounded-xl text-[13px] font-semibold"
            >
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}
