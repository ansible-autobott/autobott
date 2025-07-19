<?php

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
    exit;
}

{#
# Uncomment this to disable output compression
# $wgDisableOutputCompression = true;
#}
{% if mediawiki_config.wiki.name is defined %}
$wgSitename = "{{  mediawiki_config.wiki.name }}";
{% else %}
$wgSitename = "Mediawiki";
{% endif %}


# print detailed errors:
{% if mediawiki_config.wiki.print_exceptions is defined and mediawiki_config.wiki.print_exceptions %}

// error_reporting( -1 );
// ini_set( 'display_errors', 1 );

$wgShowExceptionDetails = true;
$wgShowDBErrorBacktrace = true;
{% endif %}

$wgMetaNamespace = "{{  mediawiki_config.wiki.namespace }}";

## The URL base path to the directory containing the wiki;
## defaults for all runtime URL paths are based off of this.
## For more information on customizing the URLs
## (like /w/index.php/Page_title to /wiki/Page_title) please see:
## https://www.mediawiki.org/wiki/Manual:Short_URL
$wgScriptPath = "";

## The protocol and server name to use in fully-qualified URLs
$wgServer = "{{ mediawiki_config.wiki.base_url}}";


## The URL path to static resources (images, scripts, etc.)
$wgResourceBasePath = $wgScriptPath;

## The URL path to the logo.  Make sure you change this from the default,
## or else you'll overwrite your logo when you upgrade!
$wgLogo = "$wgResourceBasePath/my_wiki.png";
$wgFavicon = "$wgResourceBasePath/my_wiki_favicon.png";

## UPO means: this is also a user preference option

$wgEnableEmail = true;
$wgEnableUserEmail = false; # UPO

$wgEmergencyContact = "{{ mediawiki_config.wiki.emergency_contact_mail }}";
$wgPasswordSender = "{{ mediawiki_config.wiki.password_sender_mail }}";

$wgEnotifUserTalk = false; # UPO
$wgEnotifWatchlist = false; # UPO
$wgEmailAuthentication = false;

## Database settings
$wgDBtype = "mysql";
$wgDBserver = "localhost";
$wgDBname = "{{ mediawiki_config.db.name }}";
$wgDBuser = "{{ mediawiki_config.db.user }}";
$wgDBpassword = "{{ mediawiki_config.db.pass }}";

# MySQL specific settings
$wgDBprefix = "";

# MySQL table options to use during installation or update
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";

# Experimental charset support for MySQL 5.0.
$wgDBmysql5 = false;

## Shared memory settings
$wgMainCacheType = CACHE_NONE;
$wgMemCachedServers = [];

## To enable image uploads, make sure the 'images' directory
## is writable, then set this to true:
$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";

# InstantCommons allows wiki to use images from https://commons.wikimedia.org
$wgUseInstantCommons = false;

# Periodically send a pingback to https://www.mediawiki.org/ with basic data
# about this MediaWiki instance. The Wikimedia Foundation shares this data
# with MediaWiki developers to help guide future development efforts.
$wgPingback = false;

## If you use ImageMagick (or any other shell command) on a
## Linux server, this will need to be set to the name of an
## available UTF-8 locale

$wgShellLocale = "{{ mediawiki_config.wiki.locale }}";

## Set $wgCacheDirectory to a writable directory on the web server
## to make your wiki go slightly faster. The directory should not
## be publically accessible from the web.
#$wgCacheDirectory = "$IP/cache";

# Site language code, should be one of the list in ./languages/data/Names.php
$wgLanguageCode = "{{ mediawiki_config.wiki.lang }}";

$wgSecretKey = "{{ mediawiki_config.wiki.secret_key  }}";

# Changing this will log out all existing sessions.
$wgAuthenticationTokenVersion = "1";

# Site upgrade key. Must be set to a string (default provided) to turn on the
# web installer while LocalSettings.php is in place
$wgUpgradeKey = "{{ mediawiki_config.wiki.site_upgrade_key  }}";

## For attaching licensing metadata to pages, and displaying an
## appropriate copyright notice / icon. GNU Free Documentation
## License and Creative Commons licenses are supported so far.
$wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
$wgRightsUrl = "";
$wgRightsText = "";
$wgRightsIcon = "";

# Path to the GNU diff3 utility. Used for conflict resolution.
$wgDiff3 = "/usr/bin/diff3";

# The following permissions were set based on your choice in the installer
$wgGroupPermissions['*']['createaccount'] = false;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['read'] = false;


# Enabled extensions. Most of the extensions are enabled by adding
# wfLoadExtensions('ExtensionName');
# to LocalSettings.php. Check specific extension documentation for more details.
# The following extensions were automatically enabled:
wfLoadExtension( 'Cite' );
wfLoadExtension( 'ConfirmEdit' );
wfLoadExtension( 'SyntaxHighlight_GeSHi' );


#============================================================================================================
## FILE UPLOAD
#============================================================================================================

{% if mediawiki_config.wiki.allowed_extensions is defined %}
$wgFileExtensions = array_merge( $wgFileExtensions, array( {% for item in mediawiki_config.wiki.allowed_extensions %}"{{ item }}"{% if not loop.last %}, {% endif %}{% endfor %} ) );
{% else %}
#not defined in webservice.additional_service.mediawiki_upload.allowed_extensions, falling back to default
$wgFileExtensions = array_merge( $wgFileExtensions, array(  'jpg','tiff', 'txt' ) );
{% endif %}


{% if mediawiki_config.wiki.whitelisted_extensions is defined %}
$wgProhibitedFileExtensions = array_diff( $wgProhibitedFileExtensions,  array(  {% for item in mediawiki_config.wiki.whitelisted_extensions %}"{{ item }}"{% if not loop.last %}, {% endif %}{% endfor %}  ) );
# workaround for error: "Array value found, but an array is required"
$wgProhibitedFileExtensions=array_values($wgProhibitedFileExtensions);
{% else %}
#not defined in webservice.additional_service.mediawiki_upload.whitelisted_extensions, falling back to default
//wgProhibitedFileExtensions = array_diff( wgProhibitedFileExtensions, array ('mht','zip','exe') );
{% endif %}

$wgDisableUploadScriptChecks=false;

$wgCopyUploadsFromSpecialUpload = true;
$wgAllowCopyUploads = true;

#Uploading directly from a URL ("Sideloading")
$wgGroupPermissions['user']['upload_by_url'] = true;

## allow hotlinked images to be visible
$wgAllowExternalImages = true;

#autoConfirm upload?
$wgGroupPermissions['autoconfirmed']['upload'] = true;

#============================================================================================================
## EXTENSIONS
#============================================================================================================
## VISUAL EDITOR

wfLoadExtension( 'VisualEditor' );

// Enable by default for everybody
$wgDefaultUserOptions['visualeditor-enable'] = 1;

// Optional: Set VisualEditor as the default for anonymous users
// otherwise they will have to switch to VE
// $wgDefaultUserOptions['visualeditor-editor'] = "visualeditor";

// Don't allow users to disable it
$wgHiddenPrefs[] = 'visualeditor-enable';

// OPTIONAL: Enable VisualEditor's experimental code features
$wgDefaultUserOptions['visualeditor-enable-experimental'] = 1;

## MOBILE FRONTEND

wfLoadExtension( 'MobileFrontend' );
$wgMFAutodetectMobileView = true;


#============================================================================================================
## Skins
#============================================================================================================

# Enabled skins.
# The following skins were automatically enabled:
wfLoadSkin( 'Vector' );
## Default skin: you can change the default skin. Use the internal symbolic
$wgDefaultSkin = "vector";

wfLoadSkin( 'MinervaNeue' );
$wgMinervaEnableSiteNotice=false;

#https://www.mediawiki.org/wiki/Manual:Hooks/BeforePageDisplay
function efCustomBeforePageDisplay(&$out, &$skin ) {
    //$out->addModules( array( 'bott.customization' ) );
    if($skin->getSkinName() == "vector"){
        $out->addStyle("Vector/custom.css");
    }
    if($skin->getSkinName() == "vector-2022"){
        $out->addStyle("Vector/custom-vector-2022.css");
    }
    if($skin->getSkinName() == "minerva"){
        $out->addStyle("MinervaNeue/custom.css");
    }
}
$wgHooks['BeforePageDisplay'][] = 'efCustomBeforePageDisplay';


#============================================================================================================
## Allow Raw html
#============================================================================================================
$wgRawHtml = true;



