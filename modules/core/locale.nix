{ ... }:
{
  time.timeZone = "America/New_York"; # adjust
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.timesyncd.enable = true;
}
