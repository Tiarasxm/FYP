"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";

const defaultHero = {
  titleLine1: "Train smarter.",
  titleLine2: "See real results.",
  subtitle:
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do dolor sit tincidunt ut labore et dolore magna aliqua. Dolor sit amet, consectetur adipiscing elit.",
};

const defaultFeatures = {
  sectionLabel: "Features",
  title: "Everything to crush your goals",
  items: [
    {
      title: "Personalised Plans",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
    {
      title: "Workout Tracking",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
    {
      title: "Progress Analytics",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
    {
      title: "Nutrition Support",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
    {
      title: "Streaks & Rewards",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
    {
      title: "Community Support",
      text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    },
  ],
};

const defaultSubscription = {
  sectionLabel: "Subscription Plans",
  title: "Unlock Your Best Self",
  plans: [
    {
      title: "Free",
      price: "$0",
      description:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
      features: [
        "Basic workouts",
        "Workout tracking",
        "Community Access",
        "Workout tracking",
      ],
    },
    {
      title: "Priority",
      price: "$7.99",
      description:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
      features: [
        "Workout tracking",
        "Basic workouts",
        "Workout tracking",
        "Basic workouts",
        "Workout tracking",
        "Basic workouts",
      ],
    },
  ],
};

const defaultFaq = {
  title: "FAQs",
  items: [
    {
      question: "Is ShapeRush free to use?",
      answer: "Yes, ShapeRush provides a free plan for users.",
    },
    {
      question: "Can I track weight, workout, or intermittent fasting?",
      answer: "Yes, users can track their fitness progress inside the app.",
    },
    {
      question: "What do I need to get started?",
      answer: "Create an account and download the ShapeRush app.",
    },
  ],
};

const defaultReview = {
  reviewer_name: "Luke H.",
  rating: 5,
  feedback:
    "This app is like having a personal trainer with you 24/7. The guided workouts are clear and easy to follow, and the progress tracking keeps me accountable.",
};

const featureIcons = [
  "/images/icon-personalized.png",
  "/images/icon-workout.png",
  "/images/icon-progress.png",
  "/images/icon-nutrition.png",
  "/images/icon-rewards.png",
  "/images/icon-community.png",
];

export default function HomePage() {
  const [hero, setHero] = useState(defaultHero);
  const [features, setFeatures] = useState(defaultFeatures);
  const [subscription, setSubscription] = useState(defaultSubscription);
  const [faq, setFaq] = useState(defaultFaq);
  const [featuredReviews, setFeaturedReviews] = useState([]);
  const [currentReviewIndex, setCurrentReviewIndex] = useState(0);
  const [viewerLoading, setViewerLoading] = useState(true);
  const [viewerLoggedIn, setViewerLoggedIn] = useState(false);
  const [viewerUserType, setViewerUserType] = useState(null);

  async function fetchWebsiteContent() {
    const { data, error } = await supabase
      .from("website_content")
      .select("section_key, content");

    if (error) {
      console.error("Fetch website content error:", error.message);
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
  }

  async function fetchFeaturedReviews() {
    const { data, error } = await supabase
      .from("reviews")
      .select(
        "review_id, rating, feedback, submitted_at, featured_on_website, profiles!reviews_reviewer_id_fkey(full_name)"
      )
      .eq("featured_on_website", true)
      .order("submitted_at", { ascending: false })
      .limit(6);

    if (error) {
      console.error("Fetch featured reviews error:", error.message);
      return;
    }

    const formattedReviews = (data || []).map((review) => ({
      id: review.review_id,
      reviewer_name: review.profiles?.full_name || "-",
      rating: review.rating,
      feedback: review.feedback,
      submitted_at: review.submitted_at,
      featured_on_website: review.featured_on_website,
    }));

    setFeaturedReviews(formattedReviews);
  }

  async function fetchViewer() {
    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      setViewerLoggedIn(false);
      setViewerUserType(null);
      setViewerLoading(false);
      return;
    }

    setViewerLoggedIn(true);

    const { data: profile } = await supabase
      .from("profiles")
      .select("user_type")
      .eq("id", userData.user.id)
      .single();

    setViewerUserType(profile?.user_type || null);
    setViewerLoading(false);
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    fetchWebsiteContent();
    fetchFeaturedReviews();
    fetchViewer();
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- resets the carousel index when the review list changes
    setCurrentReviewIndex(0);
  }, [featuredReviews.length]);

  useEffect(() => {
    if (featuredReviews.length <= 1) {
      return;
    }

    const timer = setInterval(() => {
      setCurrentReviewIndex((currentIndex) =>
        currentIndex === featuredReviews.length - 1 ? 0 : currentIndex + 1
      );
    }, 4000);

    return () => clearInterval(timer);
  }, [featuredReviews.length]);

  const testimonialReviews =
    featuredReviews.length > 0 ? featuredReviews : [defaultReview];

  const mainReview =
    testimonialReviews[currentReviewIndex] || testimonialReviews[0];

  function goToPreviousReview() {
    setCurrentReviewIndex((currentIndex) =>
      currentIndex === 0 ? testimonialReviews.length - 1 : currentIndex - 1
    );
  }

  function goToNextReview() {
    setCurrentReviewIndex((currentIndex) =>
      currentIndex === testimonialReviews.length - 1 ? 0 : currentIndex + 1
    );
  }

  return (
    <main className="min-h-screen bg-[#f7f7ff] text-black">
      <Navbar />

      {/* Hero */}
      <section
        id="home"
        className="relative bg-[#f8f8ff] min-h-[520px] overflow-hidden flex items-center"
      >
        <div className="w-full px-10 md:px-24 grid grid-cols-1 md:grid-cols-2 items-center gap-10">
          <div>
            <h2 className="text-[48px] md:text-[54px] leading-[1.05] font-bold">
              {hero.titleLine1 || defaultHero.titleLine1}
              <br />
              <span className="text-[#7c83e9]">
                {hero.titleLine2 || defaultHero.titleLine2}
              </span>
            </h2>

            <p className="mt-6 text-[14px] leading-6 text-gray-500 max-w-[430px]">
              {hero.subtitle || defaultHero.subtitle}
            </p>

            <Link
              href="/register"
              className="inline-block mt-7 bg-[#6c5cff] text-white px-7 py-4 rounded-xl text-[13px] font-semibold shadow-lg shadow-purple-200"
            >
              Get Started Free <span className="ml-4">→</span>
            </Link>

            <div className="mt-10 flex items-center gap-5">
              <div className="relative w-[130px] h-[52px]">
                <Image
                  src="/images/avatar-group.png"
                  alt="Active users"
                  fill
                  className="object-contain"
                />
              </div>

              <div>
                <p className="text-[18px] font-bold">50K+</p>
                <p className="text-[14px] text-gray-500">
                  Monthly Active User
                </p>
              </div>
            </div>
          </div>

          <div className="relative hidden md:block h-[500px]">
            <Image
              src="/images/hero-phones.png"
              alt="ShapeRush app preview"
              fill
              priority
              className="object-contain object-bottom"
            />
          </div>
        </div>
      </section>

      {/* Features */}
      <section
        id="features"
        className="bg-[#f0f1ff] px-10 md:px-24 py-24 grid grid-cols-1 md:grid-cols-2 gap-24 items-center"
      >
        <div className="max-w-[650px]">
          <Image
            src="/images/feature-workout.png"
            alt="Users checking workout progress"
            width={1040}
            height={780}
            className="w-full h-auto rounded-[22px]"
          />
        </div>

        <div>
          <p className="text-[#6c5cff] text-[13px] font-semibold uppercase">
            {features.sectionLabel || "Features"}
          </p>

          <h2 className="text-[24px] font-bold mt-2">
            {features.title || defaultFeatures.title}
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-x-12 gap-y-12 mt-10">
            {(features.items || defaultFeatures.items).map((item, index) => (
              <Feature
                key={index}
                icon={featureIcons[index] || featureIcons[0]}
                title={item.title}
                text={item.text}
              />
            ))}
          </div>
        </div>
      </section>

      {/* Plans */}
      <section
        id="plans"
        className="relative overflow-hidden bg-[#fafaff] px-10 md:px-24 py-24"
      >
        <h1 className="absolute bottom-[-38px] left-0 right-0 text-[150px] md:text-[180px] font-bold text-[#ececf7] z-0 text-center leading-none">
          ShapeRush
        </h1>

        <div className="relative z-10 text-center">
          <p className="text-[#6c5cff] text-[13px] font-semibold uppercase">
            {subscription.sectionLabel || "Subscription Plans"}
          </p>

          <h2 className="text-[24px] font-bold mt-2">
            {subscription.title || defaultSubscription.title}
          </h2>

          <div className="mt-12 flex flex-col md:flex-row justify-center gap-8">
            {(subscription.plans || defaultSubscription.plans).map(
              (plan, index) => {
                const planKind = getPlanKind(plan.title);
                const cta = getPlanCta(
                  planKind,
                  viewerLoading,
                  viewerLoggedIn,
                  viewerUserType
                );

                return (
                  <PlanCard
                    key={index}
                    title={plan.title}
                    price={plan.price}
                    description={plan.description}
                    features={plan.features}
                    premium={index === 1}
                    cta={cta}
                  />
                );
              }
            )}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section id="reviews" className="bg-white px-0 py-20 overflow-hidden">
        <div className="grid grid-cols-1 md:grid-cols-3 items-center gap-10">
          <div className="hidden md:flex gap-3 -ml-8">
            <PersonCard image="/images/testimonial-1.png" />
            <PersonCard image="/images/testimonial-2.png" />
            <PersonCard image="/images/testimonial-3.png" />
          </div>

          <div className="text-center px-10">
            <p className="text-[#6c5cff] text-[13px] font-semibold uppercase">
              TESTIMONIALS
            </p>

            <h2 className="text-[24px] font-bold mt-2">What Users Say</h2>

            <p className="mt-8 text-[16px] leading-7 min-h-[70px]">
              “{mainReview?.feedback || defaultReview.feedback}”
            </p>

            <p className="mt-6 text-gray-400">
              {mainReview?.reviewer_name || defaultReview.reviewer_name}
            </p>

            <p className="text-yellow-400 text-[28px] mt-2">
              {renderStars(mainReview?.rating || defaultReview.rating)}
            </p>

            <div className="flex justify-center items-center gap-3 mt-8">
              <button
                type="button"
                onClick={goToPreviousReview}
                className="text-[#6c5cff] text-[24px] font-bold px-2"
                aria-label="Previous review"
              >
                ‹
              </button>

              {testimonialReviews.slice(0, 6).map((review, index) => (
                <button
                  key={review.id || index}
                  type="button"
                  onClick={() => setCurrentReviewIndex(index)}
                  className={
                    index === currentReviewIndex
                      ? "w-5 h-2 bg-[#6c5cff] rounded-full"
                      : "w-2 h-2 bg-gray-300 rounded-full"
                  }
                  aria-label={`Show review ${index + 1}`}
                />
              ))}

              <button
                type="button"
                onClick={goToNextReview}
                className="text-[#6c5cff] text-[24px] font-bold px-2"
                aria-label="Next review"
              >
                ›
              </button>
            </div>
          </div>

          <div className="hidden md:flex gap-3 -mr-8">
            <PersonCard image="/images/testimonial-4.png" />
            <PersonCard image="/images/testimonial-5.png" />
            <PersonCard image="/images/testimonial-6.png" />
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section id="faq" className="bg-[#f8f8ff] px-10 md:px-64 py-24">
        <h2 className="text-[28px] font-bold mb-8">
          {faq.title || defaultFaq.title}
        </h2>

        {(faq.items || defaultFaq.items).map((item, index) => (
          <FAQItem
            key={index}
            question={item.question}
            answer={item.answer}
          />
        ))}
      </section>

      {/* Footer */}
      <footer className="bg-white px-10 md:px-12 py-16 grid grid-cols-1 md:grid-cols-4 gap-12">
        <div>
          <h2 className="text-[34px] font-bold">ShapeRush</h2>

          <p className="mt-5 text-[14px] leading-6 text-gray-500">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
            dolor sit tincidunt ut labore et dolore magna aliqua. Dolor sit
            amet, consectetur adipiscing elit.
          </p>

          <p className="mt-5 text-gray-500">©2026 by ShapeRush</p>
        </div>

        <FooterColumn
          title="Address"
          lines={["641 Clementi Road,", "Singapore 556431"]}
        />

        <div>
          <p className="text-[#6c5cff] text-[14px] mb-5">Legal</p>

          <div className="space-y-3 text-[15px]">
            <Link href="/privacy-policy" className="block">
              Privacy Policy
            </Link>

            <Link href="/terms-and-conditions" className="block">
              Terms and Conditions
            </Link>
          </div>
        </div>

        <FooterColumn title="Contact Us" lines={["shaperush@gmail.com"]} />
      </footer>
    </main>
  );
}

function Feature({ icon, title, text }) {
  return (
    <div>
      <div className="relative w-8 h-8">
        <Image
          src={icon}
          alt={title || "Feature"}
          fill
          className="object-contain"
        />
      </div>

      <h3 className="mt-4 text-[14px] font-bold">{title}</h3>

      <p className="mt-2 text-[12px] leading-4 text-gray-500">{text}</p>
    </div>
  );
}

function PlanCard({ title, price, description, features, premium, cta }) {
  return (
    <div
      className={`w-[310px] min-h-[390px] bg-white rounded-[22px] p-8 text-left flex flex-col ${
        premium ? "border-2 border-[#6c5cff]" : ""
      }`}
    >
      <h3 className="text-[22px] font-bold">{title}</h3>

      <p className="mt-3 text-[12px] leading-5 text-gray-500">
        {description}
      </p>

      <div className="mt-10 flex items-end">
        <p className="text-[32px] font-medium">{price}</p>
        {premium && <span className="ml-2 mb-2 text-gray-500">/month</span>}
      </div>

      <div className="h-px bg-gray-200 my-5" />

      <ul className="space-y-4 text-[13px]">
        {(features || []).map((feature, index) => (
          <PlanItem key={index} text={feature} />
        ))}
      </ul>

      {cta && (
        <div className="mt-auto pt-8">
          <PlanCtaButton cta={cta} />
        </div>
      )}
    </div>
  );
}

function PlanCtaButton({ cta }) {
  if (cta.disabled) {
    return (
      <button
        type="button"
        disabled
        className="w-full h-[48px] bg-gray-200 text-gray-500 rounded-[22px] text-[13px] font-semibold cursor-not-allowed"
      >
        {cta.label}
      </button>
    );
  }

  return (
    <Link
      href={cta.href}
      className="block w-full h-[48px] leading-[48px] text-center bg-[#6c5cff] text-white rounded-[22px] text-[13px] font-semibold hover:bg-[#5b4bea]"
    >
      {cta.label}
    </Link>
  );
}

function PlanItem({ text }) {
  if (!text) return null;

  return (
    <li className="text-[#6c5cff]">
      ✓ <span className="text-black ml-2">{text}</span>
    </li>
  );
}

function PersonCard({ image }) {
  return (
    <div className="relative w-[160px] h-[245px] rounded-xl overflow-hidden bg-gray-100">
      <Image
        src={image}
        alt="ShapeRush user testimonial"
        fill
        className="object-cover object-top"
      />
    </div>
  );
}

function FAQItem({ question, answer }) {
  return (
    <details className="border-b border-gray-200 py-5">
      <summary className="flex items-center justify-between cursor-pointer list-none">
        <p className="text-[15px]">{question}</p>
        <span className="text-[#6c5cff] text-2xl">+</span>
      </summary>

      {answer && (
        <p className="mt-4 text-[14px] leading-6 text-gray-500">{answer}</p>
      )}
    </details>
  );
}

function FooterColumn({ title, lines }) {
  return (
    <div>
      <p className="text-[#6c5cff] text-[14px] mb-5">{title}</p>

      <div className="space-y-3 text-[15px]">
        {lines.map((line) => (
          <p key={line}>{line}</p>
        ))}
      </div>
    </div>
  );
}

function renderStars(rating) {
  const value = Math.max(0, Math.min(5, Number(rating || 0)));

  return "★ ".repeat(value) + "☆ ".repeat(5 - value);
}

function getPlanKind(title) {
  const normalized = (title || "").trim().toLowerCase();

  if (normalized === "free") {
    return "free";
  }

  if (normalized === "priority") {
    return "priority";
  }

  return null;
}

function getPlanCta(planKind, viewerLoading, viewerLoggedIn, viewerUserType) {
  if (!planKind) {
    return null;
  }

  if (viewerLoading || !viewerLoggedIn) {
    return planKind === "free"
      ? { label: "Get Started Free", href: "/register" }
      : { label: "Get Priority", href: "/register" };
  }

  const normalizedType = (viewerUserType || "").trim().toLowerCase();

  if (normalizedType === "free") {
    return planKind === "free"
      ? { label: "Current Plan", disabled: true }
      : { label: "Upgrade to Priority", href: "/choose-plan" };
  }

  if (normalizedType === "priority") {
    return planKind === "free"
      ? { label: "Switch to Free", href: "/choose-plan" }
      : { label: "Current Plan", disabled: true };
  }

  return null;
}