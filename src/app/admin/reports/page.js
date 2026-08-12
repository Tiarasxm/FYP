"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";

export default function AdminReportsPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);

  const [reports, setReports] = useState([]);
  const [typeFilter, setTypeFilter] = useState("All Type");
  const [timeFilter, setTimeFilter] = useState("This Week");
  const [searchKeyword, setSearchKeyword] = useState("");
  const [selectedReport, setSelectedReport] = useState(null);

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchReports();
  }, [router]);

  async function fetchReports() {
    setLoading(true);

    const { data, error } = await supabase
      .from("reports")
      .select(
        "report_id, reporter_id, reported_user_id, post_id, content_type, report_type, details, status, submitted_at"
      )
      .eq("status", "pending")
      .order("submitted_at", { ascending: false });

    if (error) {
      console.error("Fetch reports error:", error.message);
      setReports([]);
      setLoading(false);
      return;
    }

    const rows = data || [];

    const profileIds = Array.from(
      new Set(
        rows.flatMap((row) => [row.reporter_id, row.reported_user_id]).filter(Boolean)
      )
    );

    let profileNames = {};

    if (profileIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from("profiles")
        .select("id, full_name")
        .in("id", profileIds);

      if (profilesError) {
        console.error("Fetch report profiles error:", profilesError.message);
      } else {
        profileNames = Object.fromEntries(
          (profiles || []).map((profile) => [profile.id, profile.full_name])
        );
      }
    }

    setReports(
      rows.map((row) => ({
        ...row,
        reporter_name: profileNames[row.reporter_id] || null,
        reported_user_name: profileNames[row.reported_user_id] || null,
      }))
    );

    setLoading(false);
  }

  async function handleDismiss(report) {
    const confirmed = window.confirm("Dismiss this report?");

    if (!confirmed) return;

    const { error } = await supabase
      .from("reports")
      .update({
        status: "dismissed",
      })
      .eq("report_id", report.report_id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: "dismiss_report",
      target: report.report_id,
      targetType: "report",
    });

    setReports((currentReports) =>
      currentReports.filter((item) => item.report_id !== report.report_id)
    );

    setSelectedReport(null);
  }

  async function handleRemovePost(report) {
    if (!report.post_id) {
      alert("This report has no linked content to remove.");
      return;
    }

    const confirmed = window.confirm(
      "Remove this post? This will permanently delete it and cannot be undone."
    );

    if (!confirmed) return;

    const { data: deletedContent, error: deleteError } = await supabase
      .from("posts")
      .delete()
      .eq("id", report.post_id)
      .select();

    if (deleteError) {
      alert(deleteError.message);
      return;
    }

    if (!deletedContent || deletedContent.length === 0) {
      alert("Failed to remove content: no matching post was found.");
      return;
    }

    const { error } = await supabase
      .from("reports")
      .update({
        status: "removed",
      })
      .eq("report_id", report.report_id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: "remove_post",
      target: report.report_id,
      targetType: "post",
    });

    setReports((currentReports) =>
      currentReports.filter((item) => item.report_id !== report.report_id)
    );

    setSelectedReport(null);
  }

  const filteredReports = useMemo(() => {
    let result = [...reports];

    if (typeFilter !== "All Type") {
      result = result.filter(
        (report) =>
          report.content_type?.toLowerCase() === typeFilter.toLowerCase()
      );
    }

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

      result = result.filter((report) => {
        const submittedDate = new Date(report.submitted_at);
        return submittedDate >= startDate;
      });
    }

    const keyword = searchKeyword.trim().toLowerCase();

    if (keyword) {
      result = result.filter((report) => {
        return (
          report.reporter_id?.toLowerCase().includes(keyword) ||
          report.content_type?.toLowerCase().includes(keyword) ||
          report.report_type?.toLowerCase().includes(keyword)
        );
      });
    }

    return result;
  }, [reports, typeFilter, timeFilter, searchKeyword]);

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.tableCard}>
          <div style={styles.topRow}>
            <h2 style={styles.title}>Recent Reports</h2>

            <div style={styles.filters}>
              <select
                value={typeFilter}
                onChange={(event) => setTypeFilter(event.target.value)}
                style={styles.select}
              >
                <option>All Type</option>
                <option>Post</option>
                <option>User</option>
              </select>

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
            <div style={{ ...styles.cell, flex: 1.3 }}>Reporter</div>
            <div style={{ ...styles.cell, flex: 1.1 }}>Content Type</div>
            <div style={{ ...styles.cell, flex: 1.3 }}>Report Type</div>
            <div style={{ ...styles.cell, flex: 1.4 }}>Submitted</div>
            <div style={{ ...styles.cell, flex: 1 }}></div>
          </div>

          {loading ? (
            <div style={styles.emptyMessage}>Loading reports...</div>
          ) : filteredReports.length > 0 ? (
            filteredReports.map((report) => (
              <div key={report.report_id} style={styles.tableRow}>
                <div style={{ ...styles.rowCell, flex: 1.3 }}>
                  {shortId(report.reporter_id)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.1 }}>
                  {report.content_type}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.3 }}>
                  {report.report_type}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.4 }}>
                  {formatDateTime(report.submitted_at)}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1,
                    justifyContent: "flex-end",
                    display: "flex",
                  }}
                >
                  <button
                    type="button"
                    onClick={() => setSelectedReport(report)}
                    style={styles.reviewButton}
                  >
                    Review
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No reports found</div>
          )}
        </div>
      </section>

      {selectedReport && (
        <ReportDetailPanel
          report={selectedReport}
          onClose={() => setSelectedReport(null)}
          onDismiss={handleDismiss}
          onRemovePost={handleRemovePost}
        />
      )}
    </main>
  );
}

function ReportDetailPanel({ report, onClose, onDismiss, onRemovePost }) {
  const contentType = report.content_type?.toLowerCase();
  const isPost = contentType === "post";
  const isUser = contentType === "user";

  return (
    <div style={styles.overlay}>
      <aside style={styles.detailCard}>
        <button type="button" onClick={onClose} style={styles.closeButton}>
          ×
        </button>

        <p style={styles.detailLine}>
          <strong>Reported:</strong>{" "}
          {isPost ? "Reported post" : isUser ? "Reported user" : report.content_type}
        </p>

        <p style={styles.detailLine}>
          <strong>Reporter:</strong>{" "}
          {report.reporter_name || shortId(report.reporter_id)}
        </p>

        <p style={styles.detailLine}>
          <strong>Reported User:</strong>{" "}
          {report.reported_user_name || shortId(report.reported_user_id)}
        </p>

        <p style={styles.detailLine}>
          <strong>Report Type:</strong> {report.report_type}
        </p>

        <p style={styles.detailParagraph}>
          <strong>Details:</strong> {report.details || "-"}
        </p>

        <p style={styles.detailLine}>
          <strong>Submitted:</strong> {formatDateTime(report.submitted_at)}
        </p>

        <div style={styles.actionRow}>
          <button
            type="button"
            onClick={() => onDismiss(report)}
            style={styles.dismissButton}
          >
            Dismiss
          </button>

          {isPost && (
            <button
              type="button"
              onClick={() => onRemovePost(report)}
              style={styles.removeButton}
            >
              Remove Post
            </button>
          )}

          {isUser && (
            <Link
              href="/admin/users"
              style={{
                ...styles.removeButton,
                textDecoration: "none",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              View User
            </Link>
          )}
        </div>
      </aside>
    </div>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 8);
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
    position: "relative",
  },

  content: {
    flex: 1,
    padding: "90px 0 70px",
    boxSizing: "border-box",
    display: "flex",
    justifyContent: "center",
  },

  tableCard: {
    width: "830px",
    backgroundColor: "#ffffff",
    borderRadius: "28px",
    padding: "42px 26px 34px",
    boxSizing: "border-box",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
  },

  topRow: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: "40px",
    gap: "20px",
  },

  title: {
    fontSize: "17px",
    fontWeight: "700",
    margin: 0,
  },

  filters: {
    display: "flex",
    alignItems: "center",
    gap: "14px",
    flexWrap: "wrap",
  },

  select: {
    height: "38px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    padding: "0 12px",
    fontSize: "13px",
    backgroundColor: "#ffffff",
    cursor: "pointer",
  },

  searchBox: {
    height: "38px",
    width: "210px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    display: "flex",
    alignItems: "center",
    padding: "0 10px",
    boxSizing: "border-box",
    backgroundColor: "#ffffff",
  },

  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "13px",
    backgroundColor: "transparent",
  },

  tableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dcdcdc",
    padding: "18px 10px 24px",
    color: "#8e8e8e",
    fontSize: "12px",
  },

  tableRow: {
    display: "flex",
    alignItems: "center",
    minHeight: "62px",
    borderBottom: "1px solid #dcdcdc",
    padding: "0 10px",
    boxSizing: "border-box",
  },

  cell: {
    fontWeight: "500",
  },

  rowCell: {
    fontSize: "12px",
    display: "flex",
    alignItems: "center",
  },

  reviewButton: {
    width: "82px",
    height: "34px",
    borderRadius: "18px",
    border: "none",
    backgroundColor: "#efefef",
    color: "#222222",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  emptyMessage: {
    padding: "36px 10px",
    textAlign: "center",
    color: "#888888",
    fontSize: "15px",
  },

  overlay: {
    position: "fixed",
    inset: 0,
    backgroundColor: "rgba(0, 0, 0, 0.55)",
    display: "flex",
    justifyContent: "flex-end",
    alignItems: "flex-start",
    paddingTop: "40px",
    paddingRight: "52px",
    boxSizing: "border-box",
    zIndex: 100,
  },

  detailCard: {
    width: "320px",
    backgroundColor: "#ffffff",
    borderRadius: "12px",
    padding: "26px 20px",
    boxSizing: "border-box",
    position: "relative",
  },

  closeButton: {
    position: "absolute",
    top: "16px",
    right: "16px",
    border: "none",
    backgroundColor: "transparent",
    fontSize: "26px",
    lineHeight: "26px",
    cursor: "pointer",
    color: "#777777",
  },

  detailLine: {
    fontSize: "13px",
    lineHeight: "20px",
    margin: "0 0 10px",
  },

  detailParagraph: {
    fontSize: "13px",
    lineHeight: "19px",
    margin: "14px 0 24px",
  },

  mediaRow: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    fontSize: "13px",
    margin: "0 0 12px",
  },

  mediaButton: {
    width: "68px",
    height: "28px",
    borderRadius: "6px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    color: "#999999",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  mediaButtonActive: {
    color: "#6658ff",
    border: "1px solid #6658ff",
  },

  actionRow: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "8px",
  },

  dismissButton: {
    height: "34px",
    borderRadius: "18px",
    border: "1.5px solid #6658ff",
    backgroundColor: "#ffffff",
    color: "#6658ff",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  removeButton: {
    height: "34px",
    borderRadius: "18px",
    border: "none",
    backgroundColor: "#6658ff",
    color: "#ffffff",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },
};