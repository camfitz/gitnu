console.log("test");

chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('gitnu.html', {
    'bounds': {
      'width': 800,
      'height': 600
    }
  });
});