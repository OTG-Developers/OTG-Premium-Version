function onUpdateDatabase()
    print("[DB] Updating database to version 1 (Hireling)")

    db.query([[
		CREATE TABLE IF NOT EXISTS `player_hirelings` (
            `id` INT NOT NULL PRIMARY KEY auto_increment,
            `player_id` INT NOT NULL,
            `name` varchar(255),
            `active` tinyint unsigned NOT NULL DEFAULT '0',
            `sex` tinyint unsigned NOT NULL DEFAULT '0',
            `house_id` INT,
            `posx` int(11) NOT NULL DEFAULT '0',
            `posy` int(11) NOT NULL DEFAULT '0',
            `posz` int(11) NOT NULL DEFAULT '0',
            `lookbody` int(11) NOT NULL DEFAULT '0',
            `lookfeet` int(11) NOT NULL DEFAULT '0',
            `lookhead` int(11) NOT NULL DEFAULT '0',
            `looklegs` int(11) NOT NULL DEFAULT '0',
            `looktype` int(11) NOT NULL DEFAULT '136',
            `unlocked_outfits` varchar(255),
            
            FOREIGN KEY(`player_id`) REFERENCES `players`(`id`)
                ON DELETE CASCADE,
            FOREIGN KEY(`house_id`) REFERENCES `houses`(`id`)
                ON DELETE CASCADE
		)
	]])

    return true -- true = There are others migrations file | false = this is the last migration file
end
