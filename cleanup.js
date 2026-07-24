const fs = require('fs');
const path = require('path');

function deleteFolderRecursive(directoryPath) {
  if (fs.existsSync(directoryPath)) {
    fs.readdirSync(directoryPath).forEach((file, index) => {
      const curPath = path.join(directoryPath, file);
      if (fs.lstatSync(curPath).isDirectory()) { // recurse
        deleteFolderRecursive(curPath);
      } else { // delete file
        fs.unlinkSync(curPath);
      }
    });
    fs.rmdirSync(directoryPath);
  }
}

// Fase 2 files/folders
const appDir = 'd:\\BitesLog\\app';
deleteFolderRecursive(path.join(appDir, 'lib', 'features', 'auth'));
deleteFolderRecursive(path.join(appDir, 'lib', 'features', 'feed'));
deleteFolderRecursive(path.join(appDir, 'lib', 'features', 'notifications'));
if (fs.existsSync(path.join(appDir, 'lib', 'features', 'profile', 'followers_following_page.dart'))) {
  fs.unlinkSync(path.join(appDir, 'lib', 'features', 'profile', 'followers_following_page.dart'));
}
if (fs.existsSync(path.join(appDir, 'lib', 'services', 'auth_service.dart'))) {
  fs.unlinkSync(path.join(appDir, 'lib', 'services', 'auth_service.dart'));
}
if (fs.existsSync(path.join(appDir, 'lib', 'core', 'widgets', 'threaded_comments_section.dart'))) {
  fs.unlinkSync(path.join(appDir, 'lib', 'core', 'widgets', 'threaded_comments_section.dart'));
}

// Fase 3
const apiDir = 'd:\\BitesLog\\api';
deleteFolderRecursive(apiDir);

console.log('Cleanup completed successfully.');
