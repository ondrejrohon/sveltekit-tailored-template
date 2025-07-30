export const getApi = async (url: string) => {
	const res = await fetch(url);
	const data = await res.json();
	return data;
};

export const postApi = async (url: string, body?: Record<string, unknown>) => {
	const res = await fetch(url, {
		method: 'POST',
		headers: {
			Accept: 'application/json',
			'Content-Type': 'application/json'
		},
		...(body && { body: JSON.stringify(body) })
	});

	const data = await res.json();
	return data;
};

export const putApi = async (url: string, body: Record<string, unknown>) => {
	const res = await fetch(url, {
		method: 'PUT',
		headers: {
			Accept: 'application/json',
			'Content-Type': 'application/json'
		},
		body: JSON.stringify(body)
	});

	const data = await res.json();
	return data;
};

export const deleteApi = async (url: string, body?: Record<string, unknown>) => {
	const res = await fetch(url, {
		method: 'DELETE',
		headers: {
			Accept: 'application/json',
			'Content-Type': 'application/json'
		},
		...(body && { body: JSON.stringify(body) })
	});
	const data = await res.json();
	return data;
};

export const uploadApi = async (url: string, file: File, subfolder = '', includeAudio = '') => {
	const form = new FormData();
	form.append('files', file);
	if (subfolder) form.append('subfolder', subfolder);
	if (includeAudio) form.append('includeAudio', includeAudio);

	const res = await fetch(url, {
		method: 'POST',
		headers: {
			Accept: 'application/json'
		},
		body: form
	});

	if (res.status !== 200) {
		return {
			status: res.status,
			statusText: res.statusText
		};
	}

	const data = await res.json();
	return data;
};
