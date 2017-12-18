# Spotify-Interface
Small interface for accessing some parts of Spotifys Web API. Mainly going to use this to get a playlists song list.

<h3>Steps:</h3>

<p>1.) Download this repository onto your Server, so that it looks like http://YourWebsiteHere.com/spotify/files</p>
<p>2.) Login with your Spotify account @Spotify's Developer page: <a href="https://beta.developer.spotify.com/dashboard/">here</a>.</p>
<p>3.) After logging in, create a new Spotify Developer Application (click "Create an App" button).</p>
<p>4.) Press "no" when asked if you're creating a commerical application.</p>
<p>5.) Name your app whatever you want & whatever description.</p>
<p>6.) Press the "Edit Settings" button of your App.</p>
<p>7.) Under "Redirect URIs" add your website like so: "http://YourWebsiteHere.com/spotify/callback.pl".</p>
<p>8.) Press "Save".</p>
<p>9.) Press "Show Client Secret".</p>
<p>10.) Copy your "Client ID" and "Client Secret" into the file ".config.yaml"</p>
<p>11.) Copy your "Client ID" into "NewCode.html" var client_id = "..."</p>
<p>11.) Copy your Website URL into "NewCode.html" var your_weburl = "http://YourWebsiteHere.com" (exclude paths.)</p>
<p>12.) Visit the page "NewCode.html" on your website, it should redirect you to a login screen from Spotify.</p>
<p>13.) Login to your Spotify account and press "Okay"</p>
<p>14.) It'll redirect you to http://YourWebsiteHere.com/spotify/callback.pl</p>
<p>15.) If everything went OK, you should see on callback.pl "Token OK", "Hello &lt;YourSpotifyUsername&gt;"</p>