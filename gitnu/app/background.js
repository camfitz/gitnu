console.log("test");

chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create('gitnu.html', {
    'bounds': {
      'width': 1000,
      'height': 1000
    }
  });
});