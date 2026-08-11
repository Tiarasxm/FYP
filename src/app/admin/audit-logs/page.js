"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";

export default function AdminAuditLogsPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);

  const [logs, setLogs] = useState([]);
  const [timeFilter, setTimeFilter] = useState("This Week");
  const [actionFilter, setActionFilter] = useState("All Action");
  const [adminFilter, setAdminFilter] = useState("All Admin");
  const [searchKeyword, setSearchKeyword] = useState("");

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchAuditLogs();
  }, [router]);

  async function fetchAuditLogs() {
    setLoading(true);

    const { data, error } = await supabase
      .from("audit_logs")
      .select("audit_log_id, admin_id, admin_email, action, target, target_type, created_at")
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Fetch audit logs error:", error.message);
      setLogs([]);
      setLoading(false);
      return;
    }

    setLogs(data || []);
    setLoading(false);
  }

  const actionOptions = useMemo(() => {
    const actions = new Set();

    logs.forEach((log) => {
      if (log.action) {
        actions.add(log.action);
      }
    });

    return ["All Action", ...Array.from(actions).sort()];
  }, [logs]);

  const adminOptions = useMemo(() => {
    const admins = new Set();

    logs.forEach((log) => {
      if (log.admin_email) {
        admins.add(log.admin_email);
      }
    });

    return ["All Admin", ...Array.from(admins).sort()];
  }, [logs]);

  const filteredLogs = useMemo(() => {
    let result = [...logs];

    if (timeFilter !== "All Time") {
      const now = new Date();
      const startDate = new Date();

      if (timeFilter === "Today") {
        startDate.setHours(0, 0, 0, 0);
      }

      if (timeFilter === "This Week") {
        startDate.setDate(now.getDate() - 7);
      }

      if (timeFilter === "This Month") {
        startDate.setDate(now.getDate() - 30);
      }

      result = result.filter((log) => {
        const logDate = new Date(log.created_at);
        return logDate >= startDate;
      });
    }

    if (actionFilter !== "All Action") {
      result = result.filter((log) => log.action === actionFilter);
    }

    if (adminFilter !== "All Admin") {
      result = result.filter((log) => log.admin_email === adminFilter);
    }

    const keyword = searchKeyword.trim().toLowerCase();

    if (keyword) {
      result = result.filter((log) => {
        return (
          log.admin_email?.toLowerCase().includes(keyword) ||
          log.action?.toLowerCase().includes(keyword) ||
          log.target?.toLowerCase().includes(keyword) ||
          log.target_type?.toLowerCase().includes(keyword)
        );
      });
    }

    return result;
  }, [logs, timeFilter, actionFilter, adminFilter, searchKeyword]);

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.tableCard}>
          <div style={styles.topRow}>
            <h2 style={styles.title}>System Audit Logs</h2>

            <div style={styles.filters}>
              <select
                value={timeFilter}
                onChange={(event) => setTimeFilter(event.target.value)}
                style={styles.select}
              >
                <option>Today</option>
                <option>This Week</option>
                <option>This Month</option>
                <option>All Time</option>
              </select>

              <select
                value={actionFilter}
                onChange={(event) => setActionFilter(event.target.value)}
                style={styles.select}
              >
                {actionOptions.map((action) => (
                  <option key={action}>{action}</option>
                ))}
              </select>

              <select
                value={adminFilter}
                onChange={(event) => setAdminFilter(event.target.value)}
                style={styles.select}
              >
                {adminOptions.map((admin) => (
                  <option key={admin}>{admin}</option>
                ))}
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
            <div style={{ ...styles.cell, flex: 1.3 }}>Time</div>
            <div style={{ ...styles.cell, flex: 1.4 }}>Admin</div>
            <div style={{ ...styles.cell, flex: 1.4 }}>Action</div>
            <div style={{ ...styles.cell, flex: 1.3 }}>Target</div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading audit logs...</div>
          ) : filteredLogs.length > 0 ? (
            filteredLogs.map((log) => (
              <div key={log.audit_log_id} style={styles.tableRow}>
                <div style={{ ...styles.rowCell, flex: 1.3 }}>
                  {formatDateTime(log.created_at)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.4 }}>
                  {log.admin_email || "admin"}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.4 }}>
                  {log.action}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.3 }}>
                  {log.target}
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No audit logs found</div>
          )}
        </div>
      </section>
    </main>
  );
}

function formatDateTime(value) {
  if (!value) return "-";

  const date = new Date(value);

  return date.toLocaleString("en-US", {
    month: "numeric",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
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
    padding: "90px 0 70px",
    boxSizing: "border-box",
    display: "flex",
    justifyContent: "center",
  },

  tableCard: {
    width: "1060px",
    backgroundColor: "#ffffff",
    borderRadius: "28px",
    padding: "44px 32px 34px",
    boxSizing: "border-box",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
    minHeight: "720px",
  },

  topRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "48px",
    gap: "20px",
  },

  title: {
    fontSize: "20px",
    fontWeight: "700",
    margin: 0,
    whiteSpace: "nowrap",
  },

  filters: {
    display: "flex",
    alignItems: "center",
    gap: "18px",
    flexWrap: "wrap",
  },

  select: {
    height: "42px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    padding: "0 14px",
    fontSize: "15px",
    backgroundColor: "#ffffff",
    cursor: "pointer",
  },

  searchBox: {
    height: "42px",
    width: "265px",
    borderRadius: "8px",
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
    borderBottom: "1px solid #dcdcdc",
    padding: "18px 10px 28px",
    color: "#8e8e8e",
    fontSize: "15px",
  },

  tableRow: {
    display: "flex",
    alignItems: "center",
    minHeight: "78px",
    borderBottom: "1px solid #dcdcdc",
    padding: "0 10px",
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

  emptyMessage: {
    padding: "36px 10px",
    textAlign: "center",
    color: "#888888",
    fontSize: "16px",
  },
};