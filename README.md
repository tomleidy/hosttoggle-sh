# hosttoggle.sh

A shell script to automatically toggle groups of sites for commenting and uncommenting in /etc/hosts.

## Purpose

I use /etc/hosts to redirect sites I want to avoid opening automatically to 127.0.0.1 ("hey, this site isn't loading fast enough, let's open a new tab to some other site... oh, this one's not loading fast enough..."), and there are enough FQDN that I block this way that commenting and uncommenting them individually is tedious. So I made this script that will determine if a group of sites is commented out or uncommented, and then apply the opposite to that group.

## Limitations

Only works with hosts setup as 127.0.0.1 (not IPv6).

## Usage

```
sh hosttoggle.sh social news
```

The absence of the -w argument will cause it to output the changes it's going to make.

```
sh hosttoggle.sh -w social news
```

This will either toggle or untoggle the social network and news sites configured in the script (by group). It will ask for root permissions just for applying changes. And it will alert you that it should be owned by some non-user / non-root account.

Edit site arrays in the shell script to add new sites to each category. If you're adding a new category, add it to the site_list array and the case in get_group_array().
