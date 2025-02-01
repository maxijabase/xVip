# xVip

An advanced VIP management system for SourceMod servers, built upon tVip by Totenfluch. This plugin provides automated VIP handling with a flexible duration system, detailed logging, and web integration capabilities.

## Features

- **Automated VIP Management**: Add, remove, and extend VIP status with customizable durations
- **SteamID64 Support**: Full support for SteamID64 format
- **Flexible Duration System**: Set VIP duration using days, months, or years (e.g., 30d, 6m, 1y)
- **Web Integration Ready**: Includes database structure for web panel integration
- **Detailed Logging**: Comprehensive logging of all VIP-related actions
- **In-Game Commands**: Easy-to-use commands for both admins and users
- **MySQL Support**: Reliable database storage for VIP data
- **Configurable Flags**: Customize which admin flags are assigned to VIPs

## Requirements

- SourceMod 1.10 or higher
- MySQL database
- Required extensions:
  - sourcemod
  - multicolors
  - autoexecconfig
  - timeparser

## Installation

1. Download the latest release
2. Upload the files to your server's `addons/sourcemod` directory
3. Configure your database:
   - Add the following to `addons/sourcemod/configs/databases.cfg`:
   ```
   "xVip"
   {
       "driver"      "mysql"
       "host"        "your-host"
       "database"    "your-database"
       "user"        "your-username"
       "pass"        "your-password"
   }
   ```
4. Restart your server or load the plugin using `sm plugins load xvip`

## Configuration

The plugin will automatically create its configuration file at `cfg/sourcemod/xVip.cfg` with the following options:

```
// Flags to assign to VIPs. Use custom flags when possible.
// Default: "p"
xVip_flags "p"
```

## Commands

### Admin Commands
- `sm_addvip <steamid|target> [duration] [name]` - Add a VIP
  - Example: `sm_addvip 76561198179807307 30d`
- `sm_removevip <steamid|target>` - Remove a VIP
- `sm_extendvip <steamid|target> [duration]` - Extend VIP duration

### User Commands
- `sm_vip` - Display VIP information and status

## Database Structure

The plugin creates several tables:
- `xVip_vips` - Stores VIP user data
- `xVip_logs` - Tracks all VIP-related actions
- `xVip_web_admins` - Web panel admin accounts
- `xVip_web_roles` - Web panel role definitions
- `xVip_web_config` - Web panel configuration

## Duration Format

When specifying durations, use the following format:
- `[number][d|m|y]`
  - d = days
  - m = months
  - y = years
- Examples:
  - `30d` = 30 days
  - `6m` = 6 months
  - `1y` = 1 year

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## Credits

- Original tVip plugin by Totenfluch
- xVip developed by ampere

## License

This project is licensed under the MIT License - see the LICENSE file for details.