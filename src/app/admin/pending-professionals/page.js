"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";

export default function PendingProfessionalsPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [applications, setApplications] = useState([]);
  const [searchText, setSearchText] = useState("");
  const [selectedApplication, setSelectedApplication] = useState(null);

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchApplications();
  }, [router]);

  async function fetchApplications() {
    setLoading(true);

    const { data, error } = await supabase
      .from("fitness_professional")
      .select(
        "profile_id, display_name, bio, experience, specializations, certificate_name, certificate_path, approved, submitted_at, profiles!inner(full_name, email, status, created_at)"
      )
      .or("approved.eq.false,approved.is.null")
      .neq("profiles.status", "rejected")
      .order("submitted_at", { ascending: false });

    if (error) {
      console.error("Fetch pending applications error:", error.message);
      setApplications([]);
      setLoading(false);
      return;
    }

    const formattedApplications = (data || []).map((row) => ({
      id: row.profile_id,
      full_name: row.profiles?.full_name,
      email: row.profiles?.email,
      status: row.profiles?.status,
      created_at: row.profiles?.created_at,
      display_name: row.display_name,
      bio: row.bio,
      experience: row.experience,
      specializations: row.specializations,
      certificate_name: row.certificate_name,
      certificate_path: row.certificate_path,
      approved: row.approved,
      submitted_at: row.submitted_at,
    }));

    setApplications(formattedApplications);
    setLoading(false);
  }

  async function handleApprove(application) {
    const confirmApprove = window.confirm(
      `Approve ${application.full_name || application.display_name || "this applicant"}?`
    );

    if (!confirmApprove) return;

    const { error: proError } = await supabase
      .from("fitness_professional")
      .update({
        approved: true,
      })
      .eq("profile_id", application.id);

    if (proError) {
      alert(proError.message);
      return;
    }

    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        status: "active",
      })
      .eq("id", application.id);

    if (profileError) {
      alert(profileError.message);
      return;
    }

    await createAuditLog({
      action: "approve_pro",
      target: application.id,
      targetType: "professional",
    });

    setApplications((current) =>
      current.filter((item) => item.id !== application.id)
    );
    setSelectedApplication(null);
  }

  async function handleReject(application) {
    const confirmReject = window.confirm(
      `Reject ${application.full_name || application.display_name || "this applicant"}?`
    );

    if (!confirmReject) return;

    const { error: proError } = await supabase
      .from("fitness_professional")
      .update({
        approved: false,
      })
      .eq("profile_id", application.id);

    if (proError) {
      alert(proError.message);
      return;
    }

    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        status: "rejected",
      })
      .eq("id", application.id);

    if (profileError) {
      alert(profileError.message);
      return;
    }

    await createAuditLog({
      action: "reject_pro",
      target: application.id,
      targetType: "professional",
    });

    setApplications((current) =>
      current.filter((item) => item.id !== application.id)
    );
    setSelectedApplication(null);
  }

  function handleViewDocument(application) {
  if (!application.certificate_path) {
    alert("No document uploaded.");
    return;
  }

  const { data } = supabase.storage
    .from("certifications")
    .getPublicUrl(application.certificate_path);

  if (!data?.publicUrl) {
    alert("Unable to open document.");
    return;
  }

  window.open(data.publicUrl, "_blank", "noopener,noreferrer");
}

  if (!allowed) {
    return null;
  }

  const filteredApplications = applications.filter((application) => {
    const keyword = searchText.toLowerCase();

    return (
      application.full_name?.toLowerCase().includes(keyword) ||
      application.email?.toLowerCase().includes(keyword) ||
      application.specializations?.toLowerCase().includes(keyword)
    );
  });

  return (
    <main style={styles.page}>
      <button
        type="button"
        onClick={() => router.push("/admin/dashboard")}
        style={styles.backButton}
      >
        ‹
      </button>

      <section style={styles.card}>
        <div style={styles.header}>
          <h1 style={styles.title}>Pending Professional Applications</h1>

          <div style={styles.searchBox}>
            <SearchIcon />
            <input
              type="text"
              value={searchText}
              onChange={(event) => setSearchText(event.target.value)}
              placeholder="Search"
              style={styles.searchInput}
            />
          </div>
        </div>

        <div style={styles.tableHeader}>
          <div style={styles.idColumn}>ID</div>
          <div style={styles.nameColumn}>Name</div>
          <div style={styles.emailColumn}>Email</div>
          <div style={styles.specializationColumn}>Specializations</div>
          <div style={styles.statusColumn}>Status</div>
          <div style={styles.actionColumn}></div>
        </div>

        <div style={styles.tableBody}>
          {loading ? (
            <div style={styles.emptyText}>Loading applications...</div>
          ) : filteredApplications.length === 0 ? (
            <div style={styles.emptyText}>No pending applications found.</div>
          ) : (
            filteredApplications.map((application) => (
              <div key={application.id} style={styles.tableRow}>
                <div style={styles.idColumn}>
                  {shortId(application.id)}
                </div>

                <div style={styles.nameColumn}>
                  {application.full_name || application.display_name || "-"}
                </div>

                <div style={styles.emailColumn}>
                  {application.email || "-"}
                </div>

                <div style={styles.specializationColumn}>
                  {truncateText(application.specializations || "-", 28)}
                </div>

                <div style={styles.statusColumn}>
                  <span style={styles.pendingText}>Pending</span>
                </div>

                <div style={styles.actionColumn}>
                  <button
                    type="button"
                    onClick={() => setSelectedApplication(application)}
                    style={styles.reviewButton}
                  >
                    Review
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </section>

      {selectedApplication && (
        <ApplicationDetailPanel
          application={selectedApplication}
          onClose={() => setSelectedApplication(null)}
          onApprove={handleApprove}
          onReject={handleReject}
          onViewDocument={handleViewDocument}
        />
      )}
    </main>
  );
}

function ApplicationDetailPanel({ application, onClose, onApprove, onReject, onViewDocument }) {
  const displayName =
    application.display_name || application.full_name || "Not provided";

  const submittedTime =
    application.submitted_at || application.created_at
      ? formatDateTime(application.submitted_at || application.created_at)
      : "Not provided";

  return (
    <div style={styles.overlay}>
      <aside style={styles.detailPanel}>
        <button type="button" onClick={onClose} style={styles.closeButton}>
          ×
        </button>

        <div style={styles.detailContent}>
          <p style={styles.detailLine}>
            <strong>Name:</strong> {application.full_name || "-"}
          </p>

          <p style={styles.detailLine}>
            <strong>Email:</strong> {application.email || "-"}
          </p>

          <p style={styles.detailLine}>
            <strong>Submitted:</strong> {submittedTime}
          </p>

          <h2 style={styles.sectionTitle}>PROFILE</h2>

          <p style={styles.detailLine}>
            <strong>Display:</strong> {displayName}
          </p>

          <p style={styles.detailParagraph}>
            <strong>Bio:</strong>{" "}
            {application.bio || "No professional bio provided."}
          </p>

          <p style={styles.detailLine}>
            <strong>Specializations:</strong>{" "}
            {application.specializations || "Not provided"}
          </p>

          <p style={styles.detailLine}>
            <strong>Year Exp:</strong>{" "}
            {application.experience === null || application.experience === undefined
              ? "Not provided"
              : application.experience}
          </p>

          <h2 style={styles.sectionTitle}>CERTIFICATIONS</h2>

          <div style={styles.documentRow}>
            <strong>Documents:</strong>

            <button
              type="button"
              onClick={() => onViewDocument(application)}
              style={{
                ...styles.documentButton,
                ...(application.certificate_path ? styles.documentButtonActive : {}),
              }}
            >
              View {application.certificate_name ? "(1)" : "(0)"}
            </button>
          </div>
        </div>

        <div style={styles.detailActions}>
          <button
            type="button"
            onClick={() => onReject(application)}
            style={styles.rejectButton}
          >
            Reject
          </button>

          <button
            type="button"
            onClick={() => onApprove(application)}
            style={styles.approveButton}
          >
            Approve
          </button>
        </div>
      </aside>
    </div>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 4);
}

function truncateText(text, maxLength) {
  if (!text) return "-";

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}...`;
}

function formatDateTime(value) {
  const date = new Date(value);

  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
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
      stroke="#777777"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </svg>
  );
}

const styles = {
  page: {
    minHeight: "100vh",
    backgroundColor: "#f8f8ff",
    fontFamily: "Arial, sans-serif",
    color: "#000000",
    padding: "72px 0",
    boxSizing: "border-box",
    position: "relative",
  },

  backButton: {
    position: "absolute",
    top: "72px",
    left: "88px",
    width: "54px",
    height: "54px",
    borderRadius: "50%",
    border: "none",
    backgroundColor: "#ffffff",
    boxShadow: "0 8px 18px rgba(0, 0, 0, 0.08)",
    fontSize: "34px",
    lineHeight: "34px",
    color: "#555555",
    cursor: "pointer",
  },

  card: {
    width: "1100px",
    minHeight: "680px",
    margin: "0 auto",
    backgroundColor: "#ffffff",
    borderRadius: "28px",
    padding: "38px 32px 44px",
    boxSizing: "border-box",
    boxShadow: "0 10px 24px rgba(0, 0, 0, 0.03)",
  },

  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: "50px",
  },

  title: {
    fontSize: "20px",
    fontWeight: "700",
    margin: 0,
  },

  searchBox: {
    width: "280px",
    height: "44px",
    border: "1px solid #cfcfcf",
    borderRadius: "6px",
    display: "flex",
    alignItems: "center",
    gap: "10px",
    padding: "0 12px",
    boxSizing: "border-box",
  },

  searchInput: {
    border: "none",
    outline: "none",
    width: "100%",
    fontSize: "16px",
    color: "#111111",
  },

  tableHeader: {
    display: "grid",
    gridTemplateColumns: "90px 200px 250px 230px 110px 120px",
    alignItems: "center",
    borderBottom: "1px solid #d8d8d8",
    padding: "0 10px 30px",
    boxSizing: "border-box",
    color: "#777777",
    fontSize: "15px",
  },

  tableBody: {
    width: "100%",
  },

  tableRow: {
    display: "grid",
    gridTemplateColumns: "90px 200px 250px 230px 110px 120px",
    alignItems: "center",
    minHeight: "82px",
    borderBottom: "1px solid #d8d8d8",
    padding: "0 10px",
    boxSizing: "border-box",
    fontSize: "15px",
  },

  idColumn: {},
  nameColumn: {},
  emailColumn: {},
  specializationColumn: {},
  statusColumn: {},
  actionColumn: {
    display: "flex",
    justifyContent: "flex-end",
  },

  pendingText: {
    color: "#c99300",
  },

  reviewButton: {
    width: "110px",
    height: "44px",
    borderRadius: "22px",
    border: "none",
    backgroundColor: "#f3d84e",
    color: "#000000",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
  },

  emptyText: {
    padding: "44px 10px",
    fontSize: "15px",
    color: "#777777",
  },

  overlay: {
    position: "fixed",
    inset: 0,
    backgroundColor: "rgba(0, 0, 0, 0.18)",
    display: "flex",
    justifyContent: "flex-end",
    zIndex: 100,
  },

  detailPanel: {
    width: "405px",
    minHeight: "100vh",
    backgroundColor: "#ffffff",
    padding: "28px 16px 24px",
    boxSizing: "border-box",
    display: "flex",
    flexDirection: "column",
    justifyContent: "space-between",
    boxShadow: "-8px 0 24px rgba(0, 0, 0, 0.08)",
    position: "relative",
  },

  closeButton: {
    position: "absolute",
    top: "16px",
    right: "16px",
    width: "32px",
    height: "32px",
    border: "none",
    backgroundColor: "transparent",
    fontSize: "28px",
    cursor: "pointer",
  },

  detailContent: {
    paddingTop: "8px",
  },

  detailLine: {
    fontSize: "17px",
    lineHeight: "24px",
    margin: "0 0 16px",
  },

  detailParagraph: {
    fontSize: "17px",
    lineHeight: "27px",
    margin: "0 0 16px",
  },

  sectionTitle: {
    fontSize: "17px",
    fontWeight: "700",
    color: "#9c9c9c",
    margin: "46px 0 18px",
  },

  documentRow: {
    display: "flex",
    alignItems: "center",
    gap: "12px",
    fontSize: "17px",
  },

  documentButton: {
    width: "94px",
    height: "38px",
    borderRadius: "8px",
    border: "1px solid #cfcfcf",
    backgroundColor: "#ffffff",
    color: "#999999",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
  },

  detailActions: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "10px",
  },

  rejectButton: {
    height: "44px",
    borderRadius: "24px",
    border: "1.5px solid #6658ff",
    backgroundColor: "#ffffff",
    color: "#6658ff",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
  },

  approveButton: {
    height: "44px",
    borderRadius: "24px",
    border: "none",
    backgroundColor: "#6658ff",
    color: "#ffffff",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
  },
};