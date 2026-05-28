import { describe, it, before } from 'node:test';
import fs from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';

const BASE_URL = process.env.PUBLIC_REPO_URL || 'http://localhost:8080/exist/apps/public-repo';
const USER = process.env.PUBLIC_REPO_USERNAME || 'repo';
const PASS = process.env.PUBLIC_REPO_PASSWORD || 'repo';

// base path
const BASE_PATH = new URL('.', import.meta.url).pathname;

/**
 * Helper function to publish a XAR with authentication.
 * Returns the fetch response.
 * 
 * @param {string} xarFilename - The filename of the XAR to upload, located in the fixtures directory.
 * @returns {Promise<Response>} - The fetch response from the upload request.
 */
const uploadXar = async (xarFilename) => {
    const formData = new FormData();
    // load data from fixture file
    const xarContent = await fs.readFile(join(BASE_PATH, '..', 'fixtures', xarFilename));
    const blob = new Blob([xarContent], { type: 'application/octet-stream' });
    formData.append('files[]', blob, xarFilename);

    return await fetch(`${BASE_URL}/publish`, {
        method: 'POST',
        body: formData,
        headers: {
            'Authorization': 'Basic ' + btoa(`${USER}:${PASS}`)
        }
    });
};

describe('/publish endpoint', () => {
    it('should reject unauthenticated upload with non-200 status', async () => {
        const formData = new FormData();
        const blob = new Blob(['fake-xar-content'], { type: 'application/octet-stream' });
        formData.append('files[]', blob, 'fake.xar');

        const res = await fetch(`${BASE_URL}/publish`, {
            method: 'POST',
            body: formData
        });
        // eXist may return 400 (bad multipart) or 403 (unauthorized) depending on version
        assert.ok(res.status >= 400, `Expected error status for unauthenticated upload, got ${res.status}`);
    });

    it('should redirect unauthenticated GET to login page', async () => {
        const res = await fetch(`${BASE_URL}/publish`);
        const text = await res.text();
        // Unauthenticated users should see the login form
        assert.ok(
            text.includes('Administrator Login') || text.includes('login') || res.status >= 300,
            'Expected login page or redirect for unauthenticated GET'
        );
    });

    describe('authenticated upload of test-lib.xar', () => {
        let res, body;

        before(async () => {
            res = await uploadXar('test-lib.xar');
            body = await res.json();
        });

        // We expect a 200 OK for a successful upload
        it('should upload a package with authentication', async () => {
            assert.ok(res.status === 200, `Expected 200 OK for successful upload, got ${res.status}`);
        });

        it('should return a successful upload response', async () => {
            assert.ok(body, `Expected a response body`);
        });

        it('should return a list of files that were uploaded', async () => {
            assert.equal(body.files.length, 1, `Expected one uploaded file, got ${body.files.length}`);
        });

        it('the file should have the correct name', async () => {
            assert.equal(body.files[0].name, 'test-lib-1.0.0.xar', `Expected file name 'test-lib-1.0.0.xar', got ${body.files[0].name}`);
        });
 
        it('the file should have the correct type', async () => {
            assert.equal(body.files[0].type, 'application/expath+xar', `Expected file type 'application/expath+xar', got ${body.files[0].type}`);
        });

        it('the file should have the correct size', async () => {
            assert.equal(body.files[0].size, 1364, `Expected file size 1364, got ${body.files[0].size}`);
        });
    });

    describe('authenticated upload of test-app-2.xar', () => {
        let res, body;

        before(async () => {
            res = await uploadXar('test-app-2.xar');
            body = await res.json();
        });

        // We expect a 200 OK for a successful upload
        it('should upload a package with authentication', async () => {
            assert.ok(res.status === 200, `Expected 200 OK for successful upload, got ${res.status}`);
        });

        it('should return a successful upload response', async () => {
            assert.ok(body, `Expected a response body`);
        });

        it('should return a list of files that were uploaded', async () => {
            assert.equal(body.files.length, 1, `Expected one uploaded file, got ${body.files.length}`);
        });

        it('the file should have the name with the corrected version', async () => {
            assert.equal(body.files[0].name, 'test-app-2.0.0.xar', `Expected file name 'test-app-2.0.0.xar', got ${body.files[0].name}`);
        });
 
        it('the file should have the correct type', async () => {
            assert.equal(body.files[0].type, 'application/expath+xar', `Expected file type 'application/expath+xar', got ${body.files[0].type}`);
        });

        it('the file should have the correct size', async () => {
            assert.equal(body.files[0].size, 1147, `Expected file size 1147, got ${body.files[0].size}`);
        });
    });

    describe('authenticated upload of a bad package', () => {
        let res, body;

        before(async () => {
            res = await uploadXar('broken-test-app.xar');
            body = await res.json();
        });

        // it should not be a 401 or 403
        it('should reject a bad package with authentication', async () => {
            assert.ok(res.status === 400 || res.status === 500, `Expected either 400 Bad Request or 500 Internal Server Error for a malformed package, got ${res.status}`);
        });

        it('should return an error message in the response body', async () => {
            assert.equal(body.result.error, 'Failed to extract expath-pkg.xml from XAR', 'Expected an error message in the response body');
        });

        it('should return the filename in the response body', async () => {
            assert.equal(body.result.name, 'broken-test-app.xar', 'Expected the filename in the response body');
        });
    });
});
