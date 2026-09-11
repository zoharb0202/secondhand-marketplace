const admin = require("firebase-admin");
const functions = require("firebase-functions");

const CHAT_ATTACHMENTS_PREFIX = "chat_attachments";
const TICKET_ATTACHMENTS_PREFIX = "ticket_attachments";

function claimedStoragePaths(raw) {
  if (!Array.isArray(raw)) return [];
  const paths = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") continue;
    const path = entry.storagePath;
    if (typeof path === "string" && path.length > 0) paths.push(path);
  }
  return paths;
}

function isInsideFolder(path, folder) {
  return typeof path === "string" &&
    path.startsWith(folder) &&
    path.length > folder.length &&
    !path.includes("..") &&
    !path.includes("//");
}

function reportOutOfScopePaths(claimed, folder, label) {
  const stray = claimed.filter((path) => !isInsideFolder(path, folder));
  if (stray.length > 0) {
    console.error(
        `🚨 ${label}: ${stray.length} attachment path(s) point OUTSIDE ${folder} ` +
        `and were NOT deleted: ${stray.slice(0, 5).join(", ")}`);
  }
}

async function sweepFolder(folder, label) {
  try {
    await admin.storage().bucket().deleteFiles({prefix: folder, force: true});
    console.log(`🧹 ${label}: swept ${folder}`);
    return true;
  } catch (e) {
    console.error(`⚠️ ${label}: could not sweep ${folder}:`, e);
    return false;
  }
}

const cleanupChatAttachmentsOnMessageDelete = functions.firestore
    .document("messages/{messageId}")
    .onDelete(async (snap, context) => {
      const messageId = context.params.messageId;
      const message = snap.data() || {};
      const claimed = claimedStoragePaths(message.attachments);
      if (claimed.length === 0) return null;

      const chatId = typeof message.chatId === "string" ? message.chatId : "";
      if (!chatId) {
        console.error(
            `⚠️ cleanupChatAttachmentsOnMessageDelete: message ${messageId} ` +
            `has ${claimed.length} attachment(s) but no chatId — cannot scope a sweep`);
        return null;
      }

      const label = `cleanupChatAttachmentsOnMessageDelete(${messageId})`;
      const folder = `${CHAT_ATTACHMENTS_PREFIX}/${chatId}/${messageId}/`;
      reportOutOfScopePaths(claimed, folder, label);
      await sweepFolder(folder, label);
      return null;
    });

const cleanupChatAttachmentsOnChatDelete = functions.firestore
    .document("chats/{chatId}")
    .onDelete(async (snap, context) => {
      const chatId = context.params.chatId;
      const label = `cleanupChatAttachmentsOnChatDelete(${chatId})`;
      await sweepFolder(`${CHAT_ATTACHMENTS_PREFIX}/${chatId}/`, label);
      return null;
    });

const cleanupTicketAttachmentsOnTicketDelete = functions.firestore
    .document("support_tickets/{ticketId}")
    .onDelete(async (snap, context) => {
      const ticketId = context.params.ticketId;
      const label = `cleanupTicketAttachmentsOnTicketDelete(${ticketId})`;
      await sweepFolder(`${TICKET_ATTACHMENTS_PREFIX}/${ticketId}/`, label);
      return null;
    });

module.exports = {
  cleanupChatAttachmentsOnMessageDelete,
  cleanupChatAttachmentsOnChatDelete,
  cleanupTicketAttachmentsOnTicketDelete,
  CHAT_ATTACHMENTS_PREFIX,
  TICKET_ATTACHMENTS_PREFIX,
  claimedStoragePaths,
  isInsideFolder,
};
