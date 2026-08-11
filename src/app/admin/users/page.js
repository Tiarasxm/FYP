"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";

export default function AdminUsersPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);

  const [tierFilter, setTierFilter] = useState("All Tier");
  const [statusFilter, setStatusFilter] = useState("All Status");
  const [searchKeyword, setSearchKeyword] = useState("");

  const [users, setUsers] = useState([]);

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchUsers();
  }, [router]);

  async function fetchUsers() {
    setLoading(true);

    const { data, error } = await supabase
      .from("profiles")
      .select("id, full_name, email, user_type, status")
      .in("user_type", ["Free", "Priority"])
      .order("full_name", { ascending: true });

    if (error) {
      console.error("Fetch users error:", error.message);
      setUsers([]);
      setLoading(false);
      return;
    }

    const formattedUsers = (data || []).map((user) => ({
      id: user.id,
      shortId: shortId(user.id),
      name: user.full_name || "-",
      email: user.email || "-",
      tier: user.user_type || "-",
      status: normalizeStatus(user.status),
    }));

    setUsers(formattedUsers);
    setLoading(false);
  }

  async function handleToggleStatus(user) {
    const currentStatus = user.status;
    const nextStatus = currentStatus === "Suspended" ? "active" : "suspended";

    const confirmMessage =
      currentStatus === "Suspended"
        ? `Unsuspend ${user.name}?`
        : `Restrict ${user.name}?`;

    const confirmed = window.confirm(confirmMessage);

    if (!confirmed) return;

    const { error } = await supabase
      .from("profiles")
      .update({
        status: nextStatus,
      })
      .eq("id", user.id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: nextStatus === "suspended" ? "suspend_user" : "unsuspend_user",
      target: user.id,
      targetType: "user",
    });

    setUsers((currentUsers) =>
      currentUsers.map((item) =>
        item.id === user.id
          ? {
              ...item,
              status: normalizeStatus(nextStatus),
            }
          : item
      )
    );
  }

  const filteredUsers = users.filter((user) => {
    const matchTier = tierFilter === "All Tier" || user.tier === tierFilter;

    const matchStatus =
      statusFilter === "All Status" || user.status === statusFilter;

    const keyword = searchKeyword.trim().toLowerCase();

    const matchSearch =
      keyword === "" ||
      user.shortId.toLowerCase().includes(keyword) ||
      user.name.toLowerCase().includes(keyword) ||
      user.email.toLowerCase().includes(keyword);

    return matchTier && matchStatus && matchSearch;
  });

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.tableCard}>
          <div style={styles.topRow}>
            <h2 style={styles.title}>
              Users{" "}
              <span style={styles.count}>
                ({loading ? "..." : formatNumber(users.length)})
              </span>
            </h2>

            <div style={styles.filters}>
              <select
                style={styles.select}
                value={tierFilter}
                onChange={(event) => setTierFilter(event.target.value)}
              >
                <option>All Tier</option>
                <option>Free</option>
                <option>Priority</option>
              </select>

              <select
                style={styles.select}
                value={statusFilter}
                onChange={(event) => setStatusFilter(event.target.value)}
              >
                <option>All Status</option>
                <option>Active</option>
                <option>Suspended</option>
              </select>

              <div style={styles.searchBox}>
                <SearchIcon />

                <input
                  type="text"
                  placeholder="Search"
                  value={searchKeyword}
                  onChange={(event) => setSearchKeyword(event.target.value)}
                  style={styles.searchInput}
                />
              </div>
            </div>
          </div>

          <div style={styles.tableHeader}>
            <div style={{ ...styles.cell, flex: 0.9 }}>ID</div>
            <div style={{ ...styles.cell, flex: 1.7 }}>Name</div>
            <div style={{ ...styles.cell, flex: 2.6 }}>Email</div>
            <div style={{ ...styles.cell, flex: 1.1 }}>Tier</div>
            <div style={{ ...styles.cell, flex: 1.2 }}>Status</div>
            <div style={{ ...styles.cell, flex: 1.2 }}></div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading users...</div>
          ) : filteredUsers.length > 0 ? (
            filteredUsers.map((user) => (
              <div key={user.id} style={styles.tableRow}>
                <div style={{ ...styles.rowCell, flex: 0.9 }}>
                  {user.shortId}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.7 }}>
                  {user.name}
                </div>

                <div style={{ ...styles.rowCell, flex: 2.6 }}>
                  {user.email}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.1 }}>
                  {user.tier}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.2,
                    color:
                      user.status === "Suspended" ? "#ef4444" : "#4caf50",
                  }}
                >
                  {user.status}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.2,
                    justifyContent: "flex-end",
                    display: "flex",
                  }}
                >
                  <button
                    onClick={() => handleToggleStatus(user)}
                    style={
                      user.status === "Suspended"
                        ? styles.unsuspendButton
                        : styles.restrictButton
                    }
                  >
                    {user.status === "Suspended" ? "Unsuspend" : "Restrict"}
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No users found</div>
          )}
        </div>
      </section>
    </main>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 4);
}

function normalizeStatus(status) {
  if (!status) return "Active";

  const lowerStatus = status.toLowerCase();

  if (lowerStatus === "suspended") {
    return "Suspended";
  }

  return "Active";
}

function formatNumber(value) {
  return Number(value).toLocaleString();
}

function SearchIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#8f8f8f"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      style={{ marginRight: "8px", flexShrink: 0 }}
    >
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

const styles = {
  page: {
    minHeight: "100vh",
    display: "flex",
    backgroundColor: "#f8f8ff",
    fontFamily: "Arial, sans-serif",
    color: "#000000",
  },

  content: {
    flex: 1,
    padding: "82px 58px",
    boxSizing: "border-box",
  },

  tableCard: {
    backgroundColor: "#ffffff",
    borderRadius: "26px",
    padding: "44px 30px 10px",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
    minHeight: "calc(100vh - 164px)",
    boxSizing: "border-box",
  },

  topRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "34px",
    gap: "20px",
  },

  title: {
    fontSize: "24px",
    fontWeight: "700",
    margin: 0,
  },

  count: {
    color: "#9b9b9b",
    fontWeight: "500",
  },

  filters: {
    display: "flex",
    alignItems: "center",
    gap: "18px",
    flexWrap: "wrap",
  },

  select: {
    height: "42px",
    borderRadius: "10px",
    border: "1px solid #cfcfcf",
    padding: "0 14px",
    fontSize: "15px",
    backgroundColor: "#ffffff",
    cursor: "pointer",
  },

  searchBox: {
    height: "42px",
    width: "266px",
    borderRadius: "10px",
    border: "1px solid #cfcfcf",
    display: "flex",
    alignItems: "center",
    padding: "0 12px",
    boxSizing: "border-box",
    backgroundColor: "#ffffff",
  },

  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "15px",
    backgroundColor: "transparent",
  },

  tableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dddddd",
    padding: "18px 10px",
    color: "#8e8e8e",
    fontSize: "15px",
  },

  tableRow: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #e5e5e5",
    padding: "18px 10px",
    minHeight: "78px",
    boxSizing: "border-box",
  },

  cell: {
    fontWeight: "500",
  },

  rowCell: {
    fontSize: "15px",
    display: "flex",
    alignItems: "center",
  },

  restrictButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#efefef",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
  },

  unsuspendButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#f5bcbc",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
  },

  emptyMessage: {
    padding: "36px 10px",
    textAlign: "center",
    color: "#888888",
    fontSize: "16px",
  },
};