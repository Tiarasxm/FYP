"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function Navbar() {
  const router = useRouter();
  const pathname = usePathname();
  const menuRef = useRef(null);
  const isHome = pathname === "/";

  const [loggedIn, setLoggedIn] = useState(false);
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);

  async function loadSession() {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data?.user) {
      setLoggedIn(false);
      setFullName("");
      setEmail("");
      return;
    }

    setLoggedIn(true);

    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, email")
      .eq("id", data.user.id)
      .single();

    setFullName(profile?.full_name || "");
    setEmail(profile?.email || data.user.email || "");
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    loadSession();
  }, []);

  useEffect(() => {
    if (!menuOpen) {
      return;
    }

    function handleClickOutside(event) {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setMenuOpen(false);
      }
    }

    function handleKeyDown(event) {
      if (event.key === "Escape") {
        setMenuOpen(false);
      }
    }

    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [menuOpen]);

  async function handleLogout() {
    setMenuOpen(false);
    await supabase.auth.signOut();
    router.push("/");
  }

  const avatarLetter = fullName.trim() ? fullName.trim()[0].toUpperCase() : "?";

  return (
    <nav className="sticky top-0 z-50 h-[72px] bg-white flex items-center justify-between px-10 shadow-sm">
      <Link href="/" className="text-[22px] font-bold tracking-tight">
        ShapeRush
      </Link>

      <div className="hidden md:flex items-center gap-9 text-[13px] font-medium">
        <Link href={isHome ? "#home" : "/#home"}>Home</Link>
        <Link href={isHome ? "#features" : "/#features"}>Features</Link>
        <Link href={isHome ? "#plans" : "/#plans"}>Plans</Link>
        <Link href={isHome ? "#reviews" : "/#reviews"}>Reviews</Link>
        <Link href={isHome ? "#faq" : "/#faq"}>FAQ</Link>
      </div>

      <div className="flex items-center gap-3">
        {loggedIn ? (
          <div className="relative" ref={menuRef}>
            <button
              type="button"
              onClick={() => setMenuOpen((open) => !open)}
              className="flex items-center gap-2 pl-2 pr-3 py-1.5 rounded-full hover:bg-gray-100 transition-colors"
            >
              <span className="w-8 h-8 shrink-0 rounded-full bg-[#6c5cff] text-white flex items-center justify-center text-[13px] font-bold">
                {avatarLetter}
              </span>
              <span className="text-[13px] font-semibold text-black">
                {fullName}
              </span>
              <ChevronIcon open={menuOpen} />
            </button>

            {menuOpen && (
              <div className="absolute right-0 top-[calc(100%+10px)] w-64 bg-white rounded-xl shadow-lg border border-gray-100 py-2">
                <div className="flex items-center gap-3 px-4 py-3">
                  <span className="w-9 h-9 shrink-0 rounded-full bg-[#6c5cff] text-white flex items-center justify-center text-[14px] font-bold">
                    {avatarLetter}
                  </span>
                  <div className="min-w-0">
                    <p className="text-[13px] font-semibold text-black truncate">
                      {fullName}
                    </p>
                    <p className="text-[12px] text-gray-500 truncate">
                      {email}
                    </p>
                  </div>
                </div>

                <div className="h-px bg-gray-100 my-1" />

                <Link
                  href="/profile"
                  onClick={() => setMenuOpen(false)}
                  className="block px-4 py-2 text-[13px] text-gray-700 hover:bg-gray-50"
                >
                  Profile
                </Link>
                <Link
                  href="/choose-plan"
                  onClick={() => setMenuOpen(false)}
                  className="block px-4 py-2 text-[13px] text-gray-700 hover:bg-gray-50"
                >
                  Subscription
                </Link>
                <Link
                  href="/welcome"
                  onClick={() => setMenuOpen(false)}
                  className="block px-4 py-2 text-[13px] text-gray-700 hover:bg-gray-50"
                >
                  Download
                </Link>

                <div className="h-px bg-gray-100 my-1" />

                <button
                  type="button"
                  onClick={handleLogout}
                  className="w-full text-left px-4 py-2 text-[13px] text-red-600 hover:bg-gray-50"
                >
                  Logout
                </button>
              </div>
            )}
          </div>
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

function ChevronIcon({ open }) {
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={`text-gray-500 transition-transform ${open ? "rotate-180" : ""}`}
    >
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}
