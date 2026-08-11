"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function AdminSidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function handleLogout() {
    await supabase.auth.signOut();

    localStorage.removeItem("adminLoggedIn");
    localStorage.removeItem("adminEmail");

    router.replace("/login");
  }

  function isActive(path) {
    return pathname === path;
  }

  return (
    <aside style={styles.sidebar}>
      <div style={styles.menuArea}>
        <h1 style={styles.logo}>ShapeRush</h1>

        <div style={styles.sectionTitle}>MANAGE</div>

        <nav style={styles.nav}>
          <Link href="/admin/dashboard" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/dashboard") ? styles.activeNavItem : {}),
              }}
            >
              Dashboard
            </div>
          </Link>

          <Link href="/admin/users" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/users") ? styles.activeNavItem : {}),
              }}
            >
              Users
            </div>
          </Link>

          <Link href="/admin/professionals" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/professionals")
                  ? styles.activeNavItem
                  : {}),
              }}
            >
              Professionals
            </div>
          </Link>

          <Link href="/admin/plans" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/plans") ? styles.activeNavItem : {}),
              }}
            >
              Plans
            </div>
          </Link>

          <Link href="/admin/reviews" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/reviews") ? styles.activeNavItem : {}),
              }}
            >
              Reviews
            </div>
          </Link>

          <Link href="/admin/reports" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/reports") ? styles.activeNavItem : {}),
              }}
            >
              Reports
            </div>
          </Link>
        </nav>

        <div style={styles.divider}></div>

        <div style={styles.sectionTitle}>CONTENT</div>

        <nav style={styles.nav}>
          <Link href="/admin/website" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/website") ? styles.activeNavItem : {}),
              }}
            >
              Website
            </div>
          </Link>
        </nav>

        <div style={styles.divider}></div>

        <div style={styles.sectionTitle}>SYSTEM</div>

        <nav style={styles.nav}>
          <Link href="/admin/audit-logs" style={styles.linkReset}>
            <div
              style={{
                ...styles.navItem,
                ...(isActive("/admin/audit-logs") ? styles.activeNavItem : {}),
              }}
            >
              Audit Logs
            </div>
          </Link>
        </nav>
      </div>

      <button onClick={handleLogout} style={styles.logoutButton}>
        Logout
      </button>
    </aside>
  );
}

const styles = {
  sidebar: {
    width: "280px",
    height: "100vh",
    minHeight: "100vh",
    backgroundColor: "#ffffff",
    padding: "36px 30px 26px",
    boxSizing: "border-box",
    position: "sticky",
    top: 0,
    flexShrink: 0,
    overflow: "hidden",
  },

  menuArea: {
    paddingBottom: "110px",
  },

  logo: {
    fontSize: "26px",
    fontWeight: "700",
    margin: "0 0 42px",
  },

  sectionTitle: {
    fontSize: "14px",
    color: "#a5a5a5",
    marginBottom: "18px",
    letterSpacing: "0.5px",
  },

  nav: {
    display: "flex",
    flexDirection: "column",
    gap: "20px",
  },

  navItem: {
    fontSize: "16px",
    fontWeight: "600",
    cursor: "pointer",
    color: "#111111",
  },

  activeNavItem: {
    color: "#6658ff",
  },

  linkReset: {
    textDecoration: "none",
  },

  divider: {
    height: "1px",
    backgroundColor: "#e5e5e5",
    margin: "22px 0",
  },

  logoutButton: {
    position: "absolute",
    left: "30px",
    bottom: "26px",
    width: "190px",
    height: "60px",
    borderRadius: "18px",
    border: "2px solid #6658ff",
    backgroundColor: "#ffffff",
    color: "#6658ff",
    fontSize: "16px",
    fontWeight: "700",
    cursor: "pointer",
  },
};