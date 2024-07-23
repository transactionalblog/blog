function positionAsideElements(mq) {
    if (!mq.matches) {
        return;
    }

    // Find all 'aside' elements
    const asideElements = Array.from(document.querySelectorAll('aside,.aside,.toc'));

    asideElements.sort( (lhs,rhs) => lhs.getBoundingClientRect().top - rhs.getBoundingClientRect().top);

    main_element = document.querySelector('main');
    if (main_element === null) {
        return;
    }
    baseline = main_element.getBoundingClientRect().top;

    // Iterate through the 'aside' elements from top down
    asideElements.forEach((aside, index) => {
        // Adjust the top position of each aside below the first one
        if (aside.className == 'postmeta') {
            aside.style.top = document.querySelector('h1').getBoundingClientRect().top - baseline + 'px';
        }
        if (index > 0) {
            const previousAside = asideElements[index - 1];
            const previousAsideBottom = previousAside.getBoundingClientRect().bottom;
            const myTop = aside.getBoundingClientRect().top;
            if (previousAsideBottom > myTop) {
                aside.style.top = previousAsideBottom - baseline + 'px';
            }
        }
    });
}

// Run it twice because some content (particularly charts) can take
// a while to load, but can affect layout.  So the first run quickly
// gets items in about the right place, and the second one fixes up
// any minor issues once all content is fully loaded.
window.addEventListener("DOMContentLoaded", function() {
  positionAsideElements({matches: true});
});
window.addEventListener("load", function() {
  positionAsideElements({matches: true});
});
window.matchMedia("(min-width: 920px)").addEventListener('change', positionAsideElements)