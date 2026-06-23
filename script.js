const revealItems = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15 }
  );

  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add("is-visible"));
}

const copyButtons = document.querySelectorAll("[data-copy]");
const status = document.querySelector(".copy-status");

copyButtons.forEach((button) => {
  button.addEventListener("click", async () => {
    const value = button.getAttribute("data-copy");

    try {
      await navigator.clipboard.writeText(value);
      if (status) {
        status.textContent = "Copied: " + value;
      }
    } catch {
      if (status) {
        status.textContent = "Copy manually: " + value;
      }
    }
  });
});
