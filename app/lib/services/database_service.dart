import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('biteslog.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Users (menggantikan profile lama)
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        bio TEXT,
        avatar_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Cafes (global, tidak per-user)
    await db.execute('''
      CREATE TABLE cafes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        area TEXT,
        city TEXT,
        address TEXT,
        categories TEXT,
        price TEXT,
        lat REAL,
        lng REAL,
        rating REAL DEFAULT 0,
        image_url TEXT,
        created_by TEXT
      )
    ''');

    // 3. Visits (per-user)
    await db.execute('''
      CREATE TABLE visits (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        cafe_id TEXT NOT NULL,
        rating REAL,
        review TEXT,
        favorite_drink TEXT,
        price TEXT,
        visit_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (cafe_id) REFERENCES cafes (id) ON DELETE CASCADE
      )
    ''');

    // 4. Visit Photos
    await db.execute('''
      CREATE TABLE visit_photos (
        id TEXT PRIMARY KEY,
        visit_id TEXT NOT NULL,
        photo_url TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (visit_id) REFERENCES visits (id) ON DELETE CASCADE
      )
    ''');

    // 5. Lists (per-user)
    await db.execute('''
      CREATE TABLE lists (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        cover_image TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 6. List Items
    await db.execute('''
      CREATE TABLE list_items (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        cafe_id TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists (id) ON DELETE CASCADE,
        FOREIGN KEY (cafe_id) REFERENCES cafes (id) ON DELETE CASCADE
      )
    ''');

    // 7. Watchlist (per-user)
    await db.execute('''
      CREATE TABLE watchlist (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        cafe_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (cafe_id) REFERENCES cafes (id) ON DELETE CASCADE
      )
    ''');

    // Seed Data
    await _seedCafes(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Full recreate for major schema changes
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS watchlist');
      await db.execute('DROP TABLE IF EXISTS list_items');
      await db.execute('DROP TABLE IF EXISTS lists');
      await db.execute('DROP TABLE IF EXISTS visit_photos');
      await db.execute('DROP TABLE IF EXISTS visits');
      await db.execute('DROP TABLE IF EXISTS cafes');
      await db.execute('DROP TABLE IF EXISTS profile');
      await db.execute('DROP TABLE IF EXISTS users');
      await _createDB(db, newVersion);
    } else if (oldVersion < 5) {
      await db.execute('ALTER TABLE cafes ADD COLUMN created_by TEXT');
    }
  }

  Future<void> _seedCafes(Database db) async {
    final cafes = [
      [
        'Sejiwa Coffee',
        'Bandung Wetan',
        'Kota Bandung',
        'Jl. Progo No.15, Citarum, Kec. Bandung Wetan, Kota Bandung, Jawa Barat 40115',
        ['Kopi', 'Brunch'],
        r'$$',
        'assets/cafes/sejiwa_coffee.png'
      ],
      [
        'Kopi Toko Djawa',
        'Sumur Bandung',
        'Kota Bandung',
        'Jl. Braga No.81, Braga, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40111',
        ['Kopi', 'Non-Kopi'],
        r'$',
        'assets/cafes/kopi_toko_djawa.png'
      ],
      [
        'Armor Kopi Windy Point',
        'Lembang',
        'Kabupaten Bandung Barat',
        'Jl. Pagermaneuh No.276, Pagerwangi, Kec. Lembang, Kabupaten Bandung Barat, Jawa Barat 40391',
        ['Kopi', 'Makanan Berat'],
        r'$$',
        'assets/cafes/armor_kopi.png'
      ],
      [
        'Blue Doors',
        'Sumur Bandung',
        'Kota Bandung',
        'Jl. Alkateri No.2, Braga, Kec. Sumur Bandung, Kota Bandung, Jawa Barat 40111',
        ['Kopi', 'Dessert'],
        r'$$',
        'assets/cafes/blue_doors.png'
      ],
      [
        'Noughts And Crosses Coffee',
        'Cicendo',
        'Kota Bandung',
        'Jl. Pasir Kaliki No.25-27 Blok J, Arjuna, Cicendo, Bandung City, West Java 40181',
        ['Kopi', 'Makanan Berat'],
        r'$$',
        'assets/cafes/noughts.png'
      ],
      [
        'Wheels Coffee Roasters',
        'Coblong',
        'Kota Bandung',
        'Jl. Ir. H. Juanda No.256, Sekeloa, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135',
        ['Kopi', 'Brunch'],
        r'$$',
        'assets/cafes/wheels.png'
      ],
      [
        'Kilogram Space',
        'Lengkong',
        'Kota Bandung',
        'Jl. Gatot Subroto No.160, Lkr. Sel., Kec. Lengkong, Kota Bandung, Jawa Barat 40263',
        ['Kopi', 'Non-Kopi'],
        r'$$',
        'assets/cafes/kilogram.png'
      ],
      [
        'Common Grounds',
        'Sukasari',
        'Kota Bandung',
        'Jl. Dr. Setiabudi No.49, Isola, Kec. Sukasari, Kota Bandung, Jawa Barat 40161',
        ['Kopi', 'Brunch'],
        r'$$$',
        'assets/cafes/commom.png'
      ],
      [
        'Hummingbird Eatery & Space',
        'Bandung Wetan',
        'Kota Bandung',
        'Jl. Progo No.16, Citarum, Kec. Bandung, Kota Bandung, Jawa Barat 40116',
        ['Brunch', 'Makanan Berat'],
        r'$$$',
        'assets/cafes/hummingbird.png'
      ],
      [
        'Esa Coffee & Culture',
        'Cimenyan',
        'Kabupaten Bandung',
        'Jl. Pasir Impun Atas, Cikadut, Kec. Cimenyan, Kabupaten Bandung, Jawa Barat 40194',
        ['Kopi', 'Lainnya'],
        r'$$',
        'assets/cafes/esa_coffee.png'
      ],
    ];

    const uuid = Uuid();
    for (var cafe in cafes) {
      await db.insert('cafes', {
        'id': uuid.v4(),
        'name': cafe[0],
        'area': cafe[1],
        'city': cafe[2],
        'address': cafe[3],
        'categories': jsonEncode(cafe[4]),
        'price': cafe[5],
        'image_url': cafe[6],
        'rating': 0.0,
      });
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
