setTimeout(function() {
    document.querySelector('.notice').style.display = 'none';
 }, 1000);

setTimeout(function() {
document.querySelector('.message').style.display = 'none';
}, 1000);

document.addEventListener("DOMContentLoaded", function() {
    const itemCards = document.querySelectorAll(".item-card");
  
    itemCards.forEach(card => {
      card.addEventListener("mouseenter", function() {
        const updateBtn = this.querySelector(".update-button");
        const deleteBtn = this.querySelector(".delete-button");
        updateBtn.style.display = "block";
        deleteBtn.style.display = "block";
      });
  
      card.addEventListener("mouseleave", function() {
        const updateBtn = this.querySelector(".update-button");
        const deleteBtn = this.querySelector(".delete-button");
        updateBtn.style.display = "none";
        deleteBtn.style.display = "none";
      });
    });
  });
  