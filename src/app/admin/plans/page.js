"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";

export default function AdminPlansPage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [loadingFreePlans, setLoadingFreePlans] = useState(true);
  const [loadingPersonalizedPlans, setLoadingPersonalizedPlans] =
    useState(true);

  const [freePlans, setFreePlans] = useState([]);
  const [personalizedPlans, setPersonalizedPlans] = useState([]);
  const [searchKeyword, setSearchKeyword] = useState("");

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    setAllowed(true);
    fetchFreePlans();
    fetchPersonalizedPlans();
  }, [router]);

  async function fetchFreePlans() {
    setLoadingFreePlans(true);

    const { data, error } = await supabase
      .from("free_plans")
      .select("free_plan_id, plan_name, category, status, created_at")
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Fetch free plans error:", error.message);
      setFreePlans([]);
      setLoadingFreePlans(false);
      return;
    }

    setFreePlans(data || []);
    setLoadingFreePlans(false);
  }

  async function fetchPersonalizedPlans() {
    setLoadingPersonalizedPlans(true);

    const { data, error } = await supabase
      .from("personalized_plans")
      .select("personalized_plan_id, plan_name, client_id, professional_id, created_at")
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Fetch personalized plans error:", error.message);
      setPersonalizedPlans([]);
      setLoadingPersonalizedPlans(false);
      return;
    }

    setPersonalizedPlans(data || []);
    setLoadingPersonalizedPlans(false);
  }

  async function handleToggleFreePlan(plan) {
    const nextStatus = plan.status === "hidden" ? "live" : "hidden";

    const confirmMessage =
      nextStatus === "hidden"
        ? `Hide ${plan.plan_name}?`
        : `Publish ${plan.plan_name}?`;

    const confirmed = window.confirm(confirmMessage);

    if (!confirmed) return;

    const { error } = await supabase
      .from("free_plans")
      .update({
        status: nextStatus,
      })
      .eq("free_plan_id", plan.free_plan_id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: nextStatus === "hidden" ? "hide_plan" : "publish_plan",
      target: plan.free_plan_id,
      targetType: "free_plan",
    });

    setFreePlans((currentPlans) =>
      currentPlans.map((item) =>
        item.free_plan_id === plan.free_plan_id
          ? { ...item, status: nextStatus }
          : item
      )
    );
  }

  const filteredPersonalizedPlans = personalizedPlans.filter((plan) => {
    const keyword = searchKeyword.trim().toLowerCase();

    if (!keyword) return true;

    return (
      plan.plan_name?.toLowerCase().includes(keyword) ||
      plan.client_id?.toLowerCase().includes(keyword) ||
      plan.professional_id?.toLowerCase().includes(keyword)
    );
  });

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.freePlansCard}>
          <h2 style={styles.title}>
            Free Plans{" "}
            <span style={styles.count}>
              ({loadingFreePlans ? "..." : freePlans.length})
            </span>
          </h2>

          <div style={styles.freeTableHeader}>
            <div style={{ ...styles.headerCell, flex: 1.5 }}>Plan Name</div>
            <div style={{ ...styles.headerCell, flex: 1.5 }}>Category</div>
            <div style={{ ...styles.headerCell, flex: 1.4 }}>Status</div>
            <div style={{ ...styles.headerCell, flex: 1 }}></div>
          </div>

          {loadingFreePlans ? (
            <div style={styles.emptyMessage}>Loading free plans...</div>
          ) : freePlans.length > 0 ? (
            freePlans.map((plan) => (
              <div key={plan.free_plan_id} style={styles.freeTableRow}>
                <div style={{ ...styles.rowCell, flex: 1.5 }}>
                  {plan.plan_name}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.5 }}>
                  {plan.category || "-"}
                </div>

                <div
                  style={{
                    ...styles.rowCell,
                    flex: 1.4,
                    color: plan.status === "hidden" ? "#c99300" : "#4caf50",
                  }}
                >
                  {plan.status === "hidden" ? "Hidden" : "Live"}
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
                    onClick={() => handleToggleFreePlan(plan)}
                    style={
                      plan.status === "hidden"
                        ? styles.publishButton
                        : styles.hideButton
                    }
                  >
                    {plan.status === "hidden" ? "Publish" : "Hide"}
                  </button>
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>No free plans found</div>
          )}
        </div>

        <div style={styles.personalizedPlansCard}>
          <div style={styles.personalizedTopRow}>
            <h2 style={styles.title}>
              Personalized Plans{" "}
              <span style={styles.count}>
                (
                {loadingPersonalizedPlans
                  ? "..."
                  : personalizedPlans.length}
                )
              </span>
            </h2>

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

          <div style={styles.personalizedTableHeader}>
            <div style={{ ...styles.headerCell, flex: 1.5 }}>Plan Name</div>
            <div style={{ ...styles.headerCell, flex: 1.5 }}>Client ID</div>
            <div style={{ ...styles.headerCell, flex: 1.5 }}>Professional ID</div>
          </div>

          {loadingPersonalizedPlans ? (
            <div style={styles.emptyMessage}>
              Loading personalized plans...
            </div>
          ) : filteredPersonalizedPlans.length > 0 ? (
            filteredPersonalizedPlans.map((plan) => (
              <div
                key={plan.personalized_plan_id}
                style={styles.personalizedTableRow}
              >
                <div style={{ ...styles.rowCell, flex: 1.5 }}>
                  {plan.plan_name}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.5 }}>
                  {shortId(plan.client_id)}
                </div>

                <div style={{ ...styles.rowCell, flex: 1.5 }}>
                  {shortId(plan.professional_id)}
                </div>
              </div>
            ))
          ) : (
            <div style={styles.emptyMessage}>
              No personalized plans found
            </div>
          )}
        </div>
      </section>
    </main>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 8);
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
    padding: "95px 0 70px",
    boxSizing: "border-box",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "28px",
  },

  freePlansCard: {
    width: "870px",
    backgroundColor: "#ffffff",
    borderRadius: "28px",
    padding: "42px 32px 0",
    boxSizing: "border-box",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
    overflow: "hidden",
  },

  personalizedPlansCard: {
    width: "870px",
    backgroundColor: "#ffffff",
    borderRadius: "28px",
    padding: "42px 32px 0",
    boxSizing: "border-box",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
    overflow: "hidden",
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

  freeTableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dcdcdc",
    padding: "34px 10px 26px",
    color: "#8e8e8e",
    fontSize: "15px",
  },

  freeTableRow: {
    display: "flex",
    alignItems: "center",
    minHeight: "80px",
    borderBottom: "1px solid #dcdcdc",
    padding: "0 10px",
    boxSizing: "border-box",
  },

  personalizedTopRow: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
  },

  searchBox: {
    height: "42px",
    width: "272px",
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

  personalizedTableHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dcdcdc",
    padding: "34px 10px 26px",
    color: "#8e8e8e",
    fontSize: "15px",
  },

  personalizedTableRow: {
    display: "flex",
    alignItems: "center",
    minHeight: "80px",
    borderBottom: "1px solid #dcdcdc",
    padding: "0 10px",
    boxSizing: "border-box",
  },

  headerCell: {
    fontWeight: "500",
  },

  rowCell: {
    fontSize: "15px",
    display: "flex",
    alignItems: "center",
  },

  hideButton: {
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

  publishButton: {
    minWidth: "102px",
    height: "40px",
    border: "none",
    borderRadius: "20px",
    backgroundColor: "#f3d84e",
    color: "#222222",
    fontSize: "15px",
    fontWeight: "700",
    cursor: "pointer",
    padding: "0 18px",
  },

  emptyMessage: {
    padding: "34px 10px",
    color: "#888888",
    fontSize: "16px",
    textAlign: "center",
  },
};