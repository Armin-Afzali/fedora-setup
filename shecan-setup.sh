#!/bin/bash

wifi=$1

nmcli con mod $wifi ipv4.dns "178.22.122.100 185.51.200.2"

nmcli con mod $wifi ipv4.ignore-auto-dns yes

nmcli con down $wifi && nmcli con up $wifi
