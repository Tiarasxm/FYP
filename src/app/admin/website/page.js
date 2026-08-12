"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AdminSidebar from "../components/AdminSidebar";
import { supabase } from "@/lib/supabase";
import { createAuditLog } from "@/lib/adminAuditLog";
import {
  defaultHero,
  defaultFeatures,
  defaultSubscription,
  defaultFaq,
} from "@/lib/defaultWebsiteContent";

export default function AdminWebsitePage() {
  const router = useRouter();

  const [allowed, setAllowed] = useState(false);
  const [openSection, setOpenSection] = useState("hero");
  const [loading, setLoading] = useState(true);

  const [hero, setHero] = useState(defaultHero);
  const [features, setFeatures] = useState(defaultFeatures);
  const [subscription, setSubscription] = useState(defaultSubscription);
  const [faq, setFaq] = useState(defaultFaq);

  const [featuredReviews, setFeaturedReviews] = useState([]);
  const [availableReviews, setAvailableReviews] = useState([]);

  const [uploadingFields, setUploadingFields] = useState({});
  const [uploadErrors, setUploadErrors] = useState({});

  async function fetchWebsiteContent() {
    setLoading(true);

    const { data, error } = await supabase
      .from("website_content")
      .select("section_key, content");

    if (error) {
      console.error("Fetch website content error:", error.message);
      setLoading(false);
      return;
    }

    const contentMap = {};

    (data || []).forEach((item) => {
      contentMap[item.section_key] = item.content;
    });

    setHero(contentMap.hero || defaultHero);
    setFeatures(contentMap.features || defaultFeatures);
    setSubscription(contentMap.subscription || defaultSubscription);
    setFaq(contentMap.faq || defaultFaq);

    setLoading(false);
  }

  async function fetchReviews() {
    const { data, error } = await supabase
      .from("reviews")
      .select(
        "review_id, rating, feedback, media_path, submitted_at, ai_analysis, featured_on_website, profiles!reviews_reviewer_id_fkey(full_name)"
      )
      .order("submitted_at", { ascending: false });

    if (error) {
      console.error("Fetch reviews error:", error.message);
      return;
    }

    const formattedReviews = (data || []).map((review) => ({
      id: review.review_id,
      reviewer_name: review.profiles?.full_name || "-",
      rating: review.rating,
      feedback: review.feedback,
      media_path: review.media_path,
      submitted_at: review.submitted_at,
      ai_analysis: review.ai_analysis,
      featured_on_website: review.featured_on_website,
    }));

    const positiveReviews = formattedReviews.filter(
      (review) =>
        review.featured_on_website !== true &&
        review.ai_analysis === "positive" &&
        Number(review.rating) >= 4
    );

    setFeaturedReviews(formattedReviews.filter((review) => review.featured_on_website));
    setAvailableReviews(positiveReviews);
  }

  useEffect(() => {
    const isAdminLoggedIn = localStorage.getItem("adminLoggedIn");

    if (isAdminLoggedIn !== "true") {
      router.replace("/login");
      return;
    }

    // eslint-disable-next-line react-hooks/set-state-in-effect -- synchronous local admin-auth gate check, not fetched data
    setAllowed(true);
    fetchWebsiteContent();
    fetchReviews();
  }, [router]);

  async function saveSection(sectionKey, content) {
    const { error } = await supabase.from("website_content").upsert({
      section_key: sectionKey,
      content,
      updated_at: new Date().toISOString(),
    });

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: "updated_website_content",
      target: sectionKey,
      targetType: "website_section",
    });

    alert("Updated successfully.");
  }

  async function handleImageUpload({
    file,
    folder,
    trackingKey,
    contentKey,
    section,
    setSection,
  }) {
    if (!file) return;

    setUploadingFields((prev) => ({ ...prev, [trackingKey]: true }));
    setUploadErrors((prev) => ({ ...prev, [trackingKey]: "" }));

    const safeName = file.name.replace(/\s+/g, "-");
    const filePath = `${folder}/${Date.now()}-${safeName}`;

    const { error: storageError } = await supabase.storage
      .from("website-images")
      .upload(filePath, file);

    if (storageError) {
      setUploadErrors((prev) => ({ ...prev, [trackingKey]: storageError.message }));
      setUploadingFields((prev) => ({ ...prev, [trackingKey]: false }));
      return;
    }

    const { data } = supabase.storage
      .from("website-images")
      .getPublicUrl(filePath);

    setSection({ ...section, [contentKey]: data.publicUrl });
    setUploadingFields((prev) => ({ ...prev, [trackingKey]: false }));
  }

  async function addReview(review) {
    const { error } = await supabase
      .from("reviews")
      .update({ featured_on_website: true })
      .eq("review_id", review.id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: "add_featured_review",
      target: review.id,
      targetType: "review",
    });

    fetchReviews();
  }

  async function removeReview(review) {
    const { error } = await supabase
      .from("reviews")
      .update({ featured_on_website: false })
      .eq("review_id", review.id);

    if (error) {
      alert(error.message);
      return;
    }

    await createAuditLog({
      action: "remove_featured_review",
      target: review.id,
      targetType: "review",
    });

    fetchReviews();
  }

  if (!allowed) {
    return null;
  }

  return (
    <main style={styles.page}>
      <AdminSidebar />

      <section style={styles.content}>
        <div style={styles.wrapper}>
          {loading ? (
            <div style={styles.loadingCard}>Loading website content...</div>
          ) : (
            <>
              <AccordionHeader
                number="1."
                title="Hero Section"
                open={openSection === "hero"}
                onClick={() =>
                  setOpenSection(openSection === "hero" ? "" : "hero")
                }
              />

              {openSection === "hero" && (
                <section style={styles.sectionBody}>
                  <Field
                    label="Title line 1"
                    value={hero.titleLine1}
                    onChange={(value) =>
                      setHero({ ...hero, titleLine1: value })
                    }
                    maxLength={20}
                  />

                  <Field
                    label="Title line 2"
                    value={hero.titleLine2}
                    onChange={(value) =>
                      setHero({ ...hero, titleLine2: value })
                    }
                    maxLength={20}
                  />

                  <TextArea
                    label="Subtitle"
                    value={hero.subtitle}
                    onChange={(value) =>
                      setHero({ ...hero, subtitle: value })
                    }
                    maxLength={100}
                  />

                  <ImageField
                    label="Hero Phone Mockup"
                    value={hero.image_url}
                    defaultSrc="/images/hero-phones.png"
                    uploading={!!uploadingFields.heroImage}
                    error={uploadErrors.heroImage}
                    onUpload={(file) =>
                      handleImageUpload({
                        file,
                        folder: "hero",
                        trackingKey: "heroImage",
                        contentKey: "image_url",
                        section: hero,
                        setSection: setHero,
                      })
                    }
                    onReset={() => setHero({ ...hero, image_url: null })}
                  />

                  <ImageField
                    label="Avatar Group"
                    value={hero.avatar_group_url}
                    defaultSrc="/images/avatar-group.png"
                    uploading={!!uploadingFields.heroAvatar}
                    error={uploadErrors.heroAvatar}
                    onUpload={(file) =>
                      handleImageUpload({
                        file,
                        folder: "hero",
                        trackingKey: "heroAvatar",
                        contentKey: "avatar_group_url",
                        section: hero,
                        setSection: setHero,
                      })
                    }
                    onReset={() =>
                      setHero({ ...hero, avatar_group_url: null })
                    }
                  />

                  <UpdateButton onClick={() => saveSection("hero", hero)} />
                </section>
              )}

              <AccordionHeader
                number="2."
                title="Features Section"
                open={openSection === "features"}
                onClick={() =>
                  setOpenSection(openSection === "features" ? "" : "features")
                }
              />

              {openSection === "features" && (
                <section style={styles.sectionBody}>
                  <Field
                    label="Title"
                    value={features.title}
                    onChange={(value) =>
                      setFeatures({ ...features, title: value })
                    }
                    maxLength={50}
                  />

                  <ImageField
                    label="Features Image"
                    value={features.image_url}
                    defaultSrc="/images/feature-workout.png"
                    uploading={!!uploadingFields.featuresImage}
                    error={uploadErrors.featuresImage}
                    onUpload={(file) =>
                      handleImageUpload({
                        file,
                        folder: "features",
                        trackingKey: "featuresImage",
                        contentKey: "image_url",
                        section: features,
                        setSection: setFeatures,
                      })
                    }
                    onReset={() =>
                      setFeatures({ ...features, image_url: null })
                    }
                  />

                  {features.items.map((item, index) => (
                    <div key={index}>
                      <Field
                        label={`Subtitle ${index + 1}`}
                        value={item.title}
                        onChange={(value) => {
                          const nextItems = [...features.items];
                          nextItems[index] = {
                            ...nextItems[index],
                            title: value,
                          };

                          setFeatures({ ...features, items: nextItems });
                        }}
                        maxLength={30}
                      />

                      <Field
                        label={`Text ${index + 1}`}
                        value={item.text}
                        onChange={(value) => {
                          const nextItems = [...features.items];
                          nextItems[index] = {
                            ...nextItems[index],
                            text: value,
                          };

                          setFeatures({ ...features, items: nextItems });
                        }}
                        maxLength={100}
                      />
                    </div>
                  ))}

                  <UpdateButton
                    onClick={() => saveSection("features", features)}
                  />
                </section>
              )}

              <AccordionHeader
                number="3."
                title="Subscription Plans Section"
                open={openSection === "subscription"}
                onClick={() =>
                  setOpenSection(
                    openSection === "subscription" ? "" : "subscription"
                  )
                }
              />

              {openSection === "subscription" && (
                <section style={styles.sectionBody}>
                  <Field
                    label="Title"
                    value={subscription.title}
                    onChange={(value) =>
                      setSubscription({ ...subscription, title: value })
                    }
                    maxLength={50}
                  />

                  {subscription.plans.map((plan, planIndex) => (
                    <div key={planIndex} style={styles.planBlock}>
                      <h3 style={styles.planTitle}>Tier {planIndex + 1}</h3>

                      <Field
                        label="Tier Name"
                        value={plan.title}
                        onChange={(value) => {
                          const nextPlans = [...subscription.plans];
                          nextPlans[planIndex] = {
                            ...nextPlans[planIndex],
                            title: value,
                          };

                          setSubscription({
                            ...subscription,
                            plans: nextPlans,
                          });
                        }}
                        maxLength={20}
                      />

                      <Field
                        label="Tier Description"
                        value={plan.description}
                        onChange={(value) => {
                          const nextPlans = [...subscription.plans];
                          nextPlans[planIndex] = {
                            ...nextPlans[planIndex],
                            description: value,
                          };

                          setSubscription({
                            ...subscription,
                            plans: nextPlans,
                          });
                        }}
                        maxLength={100}
                      />

                      <Field
                        label="Tier Price"
                        value={plan.price}
                        onChange={(value) => {
                          const nextPlans = [...subscription.plans];
                          nextPlans[planIndex] = {
                            ...nextPlans[planIndex],
                            price: value,
                          };

                          setSubscription({
                            ...subscription,
                            plans: nextPlans,
                          });
                        }}
                        maxLength={10}
                      />

                      {plan.features.map((feature, featureIndex) => (
                        <Field
                          key={featureIndex}
                          label={`Tier ${planIndex + 1} F${featureIndex + 1}`}
                          value={feature}
                          onChange={(value) => {
                            const nextPlans = [...subscription.plans];
                            const nextFeatures = [...nextPlans[planIndex].features];

                            nextFeatures[featureIndex] = value;

                            nextPlans[planIndex] = {
                              ...nextPlans[planIndex],
                              features: nextFeatures,
                            };

                            setSubscription({
                              ...subscription,
                              plans: nextPlans,
                            });
                          }}
                          maxLength={30}
                        />
                      ))}
                    </div>
                  ))}

                  <UpdateButton
                    onClick={() => saveSection("subscription", subscription)}
                  />
                </section>
              )}

              <AccordionHeader
                number="4."
                title="Testimonials Section"
                open={openSection === "testimonials"}
                onClick={() =>
                  setOpenSection(
                    openSection === "testimonials" ? "" : "testimonials"
                  )
                }
              />

              {openSection === "testimonials" && (
                <section style={styles.sectionBody}>
                  <h3 style={styles.reviewTitle}>
                    Featured on Website{" "}
                    <span style={styles.muted}>
                      (Must be 6)
                    </span>
                  </h3>

                  <ReviewTable
                    reviews={featuredReviews}
                    actionLabel="Remove"
                    onAction={removeReview}
                  />

                  <h3 style={{ ...styles.reviewTitle, marginTop: "46px" }}>
                    AI-Filtered Review{" "}
                    <span style={styles.muted}>
                      ({availableReviews.length})
                    </span>
                  </h3>

                  <ReviewTable
                    reviews={availableReviews}
                    actionLabel="Add"
                    onAction={addReview}
                  />

                  <UpdateButton onClick={() => alert("Testimonials updated.")} />
                </section>
              )}

              <AccordionHeader
                number="5."
                title="FAQ Section"
                open={openSection === "faq"}
                onClick={() =>
                  setOpenSection(openSection === "faq" ? "" : "faq")
                }
              />

              {openSection === "faq" && (
                <section style={styles.sectionBody}>
                  <Field
                    label="Title"
                    value={faq.title}
                    onChange={(value) => setFaq({ ...faq, title: value })}
                    maxLength={50}
                  />

                  {faq.items.map((item, index) => (
                    <div key={index}>
                      <Field
                        label={`Question ${index + 1}`}
                        value={item.question}
                        onChange={(value) => {
                          const nextItems = [...faq.items];
                          nextItems[index] = {
                            ...nextItems[index],
                            question: value,
                          };

                          setFaq({ ...faq, items: nextItems });
                        }}
                        maxLength={100}
                      />

                      <Field
                        label={`Answer ${index + 1}`}
                        value={item.answer}
                        onChange={(value) => {
                          const nextItems = [...faq.items];
                          nextItems[index] = {
                            ...nextItems[index],
                            answer: value,
                          };

                          setFaq({ ...faq, items: nextItems });
                        }}
                        maxLength={100}
                      />
                    </div>
                  ))}

                  <UpdateButton onClick={() => saveSection("faq", faq)} />
                </section>
              )}
            </>
          )}
        </div>
      </section>
    </main>
  );
}

function AccordionHeader({ number, title, open, onClick }) {
  return (
    <button type="button" onClick={onClick} style={styles.accordionHeader}>
      <span>
        {number} {title}
      </span>
      <span>{open ? "▴" : "▾"}</span>
    </button>
  );
}

function Field({ label, value, onChange, maxLength }) {
  return (
    <div style={styles.fieldGroup}>
      <label style={styles.label}>
        {label}{" "}
        {maxLength && <span style={styles.muted}>(max {maxLength} char)</span>}
      </label>

      <input
        type="text"
        value={value || ""}
        maxLength={maxLength}
        onChange={(event) => onChange(event.target.value)}
        style={styles.input}
      />
    </div>
  );
}

function TextArea({ label, value, onChange, maxLength }) {
  return (
    <div style={styles.fieldGroup}>
      <label style={styles.label}>
        {label}{" "}
        {maxLength && <span style={styles.muted}>(max {maxLength} char)</span>}
      </label>

      <textarea
        value={value || ""}
        maxLength={maxLength}
        onChange={(event) => onChange(event.target.value)}
        style={styles.textarea}
      />
    </div>
  );
}

function ImageField({
  label,
  value,
  defaultSrc,
  uploading,
  error,
  onUpload,
  onReset,
}) {
  return (
    <div style={styles.fieldGroup}>
      <label style={styles.label}>{label}</label>

      {/* eslint-disable-next-line @next/next/no-img-element -- admin-only thumbnail preview, not part of the served landing page */}
      <img src={value || defaultSrc} alt={label} style={styles.imagePreview} />

      <input
        type="file"
        accept="image/png, image/jpeg, image/webp"
        disabled={uploading}
        onChange={(event) => {
          const file = event.target.files?.[0];

          if (file) {
            onUpload(file);
          }

          event.target.value = "";
        }}
        style={styles.fileInput}
      />

      {uploading && <p style={styles.muted}>Uploading...</p>}
      {error && <p style={styles.errorText}>{error}</p>}

      {value && (
        <button type="button" onClick={onReset} style={styles.resetButton}>
          Reset to default
        </button>
      )}
    </div>
  );
}

function UpdateButton({ onClick }) {
  return (
    <button type="button" onClick={onClick} style={styles.updateButton}>
      Update
    </button>
  );
}

function ReviewTable({ reviews, actionLabel, onAction }) {
  return (
    <div>
      <div style={styles.reviewHeader}>
        <div style={{ flex: 0.8 }}>Review ID</div>
        <div style={{ flex: 1 }}>Name</div>
        <div style={{ flex: 0.9 }}>Rating</div>
        <div style={{ flex: 1.6 }}>Feedback</div>
        <div style={{ flex: 1 }}>Submitted</div>
        <div style={{ flex: 0.8 }}>Media</div>
        <div style={{ flex: 0.8 }}></div>
      </div>

      {reviews.length > 0 ? (
        reviews.map((review) => (
          <div key={review.id} style={styles.reviewRow}>
            <div style={{ flex: 0.8 }}>{shortId(review.id)}</div>
            <div style={{ flex: 1 }}>{review.reviewer_name || "-"}</div>

            <div style={{ flex: 0.9 }}>
              <span style={styles.starText}>{renderStars(review.rating)}</span>
              <br />
              <span style={styles.muted}>({review.rating}/5)</span>
            </div>

            <div style={{ flex: 1.6 }}>
              {truncateText(review.feedback || "-", 42)}
            </div>

            <div style={{ flex: 1 }}>{formatDateTime(review.submitted_at)}</div>

            <div style={{ flex: 0.8 }}>
              <button style={styles.smallButton}>View</button>
            </div>

            <div style={{ flex: 0.8 }}>
              <button
                type="button"
                onClick={() => onAction(review)}
                style={styles.smallButton}
              >
                {actionLabel}
              </button>
            </div>
          </div>
        ))
      ) : (
        <div style={styles.emptyText}>No reviews found.</div>
      )}
    </div>
  );
}

function shortId(id) {
  if (!id) return "-";
  return id.slice(0, 4);
}

function renderStars(rating) {
  const value = Number(rating || 0);
  return "★".repeat(value) + "☆".repeat(5 - value);
}

function truncateText(text, maxLength) {
  if (!text) return "-";
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
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
    padding: "78px 0",
    display: "flex",
    justifyContent: "center",
    boxSizing: "border-box",
  },

  wrapper: {
    width: "670px",
  },

  loadingCard: {
    backgroundColor: "#ffffff",
    borderRadius: "18px",
    padding: "30px",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
  },

  accordionHeader: {
    width: "100%",
    height: "42px",
    border: "none",
    borderRadius: "11px",
    backgroundColor: "#6658ff",
    color: "#ffffff",
    padding: "0 18px",
    fontSize: "14px",
    fontWeight: "700",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    cursor: "pointer",
    marginBottom: "10px",
  },

  sectionBody: {
    backgroundColor: "#ffffff",
    borderRadius: "0 0 20px 20px",
    padding: "24px 12px 20px",
    marginTop: "-10px",
    marginBottom: "12px",
    boxShadow: "0 10px 28px rgba(0, 0, 0, 0.04)",
  },

  fieldGroup: {
    marginBottom: "14px",
  },

  label: {
    display: "block",
    fontSize: "12px",
    fontWeight: "700",
    marginBottom: "8px",
  },

  muted: {
    color: "#999999",
    fontWeight: "500",
  },

  input: {
    width: "100%",
    height: "36px",
    border: "1px solid #d1d1d1",
    borderRadius: "8px",
    padding: "0 12px",
    fontSize: "13px",
    boxSizing: "border-box",
    outline: "none",
  },

  textarea: {
    width: "100%",
    height: "72px",
    border: "1px solid #d1d1d1",
    borderRadius: "8px",
    padding: "10px 12px",
    fontSize: "13px",
    boxSizing: "border-box",
    outline: "none",
    resize: "none",
  },

  imagePreview: {
    width: "100%",
    maxHeight: "180px",
    objectFit: "cover",
    borderRadius: "10px",
    border: "1px solid #e5e5e5",
    marginBottom: "10px",
    backgroundColor: "#f5f5f8",
  },

  fileInput: {
    width: "100%",
    fontSize: "12px",
  },

  errorText: {
    color: "#e63946",
    fontSize: "12px",
    marginTop: "6px",
  },

  resetButton: {
    marginTop: "10px",
    height: "32px",
    padding: "0 14px",
    border: "1px solid #6658ff",
    borderRadius: "8px",
    backgroundColor: "#ffffff",
    color: "#6658ff",
    fontSize: "12px",
    fontWeight: "700",
    cursor: "pointer",
  },

  updateButton: {
    width: "100%",
    height: "40px",
    border: "none",
    borderRadius: "10px",
    backgroundColor: "#6658ff",
    color: "#ffffff",
    fontSize: "13px",
    fontWeight: "700",
    cursor: "pointer",
    marginTop: "8px",
  },

  planBlock: {
    marginTop: "18px",
    paddingTop: "8px",
  },

  planTitle: {
    fontSize: "14px",
    margin: "0 0 12px",
  },

  reviewTitle: {
    fontSize: "14px",
    margin: "0 0 18px",
  },

  reviewHeader: {
    display: "flex",
    alignItems: "center",
    borderBottom: "1px solid #dddddd",
    padding: "10px 0",
    color: "#888888",
    fontSize: "11px",
  },

  reviewRow: {
    display: "flex",
    alignItems: "center",
    minHeight: "54px",
    borderBottom: "1px solid #e5e5e5",
    fontSize: "11px",
  },

  starText: {
    color: "#f5b800",
    letterSpacing: "1px",
  },

  smallButton: {
    minWidth: "58px",
    height: "28px",
    border: "none",
    borderRadius: "16px",
    backgroundColor: "#efefef",
    color: "#222222",
    fontSize: "11px",
    fontWeight: "700",
    cursor: "pointer",
  },

  emptyText: {
    padding: "20px 0",
    color: "#888888",
    fontSize: "12px",
  },
};